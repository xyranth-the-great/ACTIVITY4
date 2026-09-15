-- =====================================================================
-- Laboratory 4-A — Role-Based Asset Transaction and Approval Management
-- Supabase schema: tables, enums, RLS policies, RPC functions, audit trail
--
-- Run this whole file once in the Supabase SQL editor (Project > SQL Editor)
-- on a fresh project. It is idempotent-ish (uses IF NOT EXISTS / OR REPLACE
-- where possible) but is intended for a single clean run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Extensions
-- ---------------------------------------------------------------------
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1. Enum types
-- ---------------------------------------------------------------------
do $$ begin
  create type user_role as enum ('admin', 'staff', 'requester');
exception when duplicate_object then null; end $$;

do $$ begin
  create type equipment_status as enum ('available', 'borrowed', 'maintenance', 'damaged', 'retired');
exception when duplicate_object then null; end $$;

do $$ begin
  create type request_status as enum ('pending', 'approved', 'rejected', 'released', 'returned', 'overdue', 'closed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type item_condition as enum ('good', 'damaged');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------

-- profiles: 1-1 extension of auth.users, carries the app role
create table if not exists profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null,
  email       text not null,
  role        user_role not null default 'requester',
  created_at  timestamptz not null default now()
);

-- equipment: the loanable inventory
create table if not exists equipment (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,
  name         text not null,
  category     text,
  description  text,
  status       equipment_status not null default 'available',
  created_by   uuid references profiles(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- borrowing_requests: the approval workflow / state machine
create table if not exists borrowing_requests (
  id               uuid primary key default gen_random_uuid(),
  equipment_id     uuid not null references equipment(id),
  requester_id     uuid not null references profiles(id),
  purpose          text not null,
  status           request_status not null default 'pending',
  requested_at     timestamptz not null default now(),
  reviewed_by      uuid references profiles(id),
  reviewed_at      timestamptz,
  rejection_reason text,
  released_by      uuid references profiles(id),
  released_at      timestamptz,
  due_at           timestamptz,
  returned_at      timestamptz,
  received_by      uuid references profiles(id),
  return_condition item_condition,
  return_notes     text,
  closed_at        timestamptz
);

create index if not exists idx_br_requester on borrowing_requests(requester_id);
create index if not exists idx_br_equipment on borrowing_requests(equipment_id);
create index if not exists idx_br_status on borrowing_requests(status);

-- audit_logs: append-only trail (BR-A4-10)
create table if not exists audit_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references profiles(id),
  action      text not null,
  module      text not null,
  record_id   text,
  description text,
  created_at  timestamptz not null default now()
);

create index if not exists idx_audit_created on audit_logs(created_at desc);

-- ---------------------------------------------------------------------
-- 3. Helper: current user's role (used inside RLS policies)
-- ---------------------------------------------------------------------
create or replace function current_role_name()
returns user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from profiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- 4. New-user trigger: every auth.users signup gets a profile row.
--    Self-registration always lands as 'requester'; an Administrator
--    promotes accounts to 'staff' / 'admin' afterwards (admin_set_user_role).
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    new.email,
    'requester'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------------------
-- 5. Row Level Security
--
-- Design choice: borrowing_requests and audit_logs have NO direct
-- insert/update client policies. Every state transition and every log
-- entry is written exclusively through the SECURITY DEFINER functions
-- in section 6, which re-check the caller's role and the record's
-- current state before writing anything. This means authorization is
-- enforced twice: once in the UI (buttons/routes hidden by role) and
-- once in the database (the functions refuse to run for the wrong
-- role or the wrong state, and raw table writes are blocked entirely).
-- ---------------------------------------------------------------------
alter table profiles enable row level security;
alter table equipment enable row level security;
alter table borrowing_requests enable row level security;
alter table audit_logs enable row level security;

-- profiles ---------------------------------------------------------
-- Admin and Staff both need to see who a request/return belongs to
-- (Staff release/return equipment on behalf of a requester), so both
-- roles can read all profiles; a Requester can only read their own.
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles
  for select using (id = auth.uid() or current_role_name() in ('admin', 'staff'));

drop policy if exists profiles_update_self on profiles;
create policy profiles_update_self on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- equipment ----------------------------------------------------------
drop policy if exists equipment_select on equipment;
create policy equipment_select on equipment
  for select using (auth.role() = 'authenticated');

drop policy if exists equipment_insert on equipment;
create policy equipment_insert on equipment
  for insert with check (current_role_name() in ('admin', 'staff'));

drop policy if exists equipment_update on equipment;
create policy equipment_update on equipment
  for update using (current_role_name() in ('admin', 'staff'));

drop policy if exists equipment_delete on equipment;
create policy equipment_delete on equipment
  for delete using (current_role_name() = 'admin');

-- borrowing_requests ---------------------------------------------------
-- Read-only at the table level; every write goes through the RPCs below.
drop policy if exists br_select on borrowing_requests;
create policy br_select on borrowing_requests
  for select using (
    requester_id = auth.uid() or current_role_name() in ('admin', 'staff')
  );

-- audit_logs -------------------------------------------------------
-- Administrator-only, read-only (no update/delete policy exists for
-- anyone, including admin, so the trail cannot be edited via the API).
drop policy if exists audit_select on audit_logs;
create policy audit_select on audit_logs
  for select using (current_role_name() = 'admin');

-- ---------------------------------------------------------------------
-- 6. RPC functions — the workflow's real business logic.
--    Each one: checks the caller's role, checks the record's current
--    state, performs the update, and writes an audit_log row, all in
--    one transaction.
-- ---------------------------------------------------------------------

-- 6.1 Requester / Staff / Admin: submit a borrowing request
create or replace function submit_borrow_request(p_equipment_id uuid, p_purpose text)
returns borrowing_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status equipment_status;
  v_req    borrowing_requests;
begin
  if p_purpose is null or length(trim(p_purpose)) = 0 then
    raise exception 'Purpose is required';
  end if;

  select status into v_status from equipment where id = p_equipment_id for update;
  if v_status is null then
    raise exception 'Equipment not found';
  end if;

  -- BR-A4-01 / BR-A4-09: only available equipment may be requested
  if v_status <> 'available' then
    raise exception 'BR-A4-01/BR-A4-09: equipment is not available (current status: %)', v_status;
  end if;

  insert into borrowing_requests (equipment_id, requester_id, purpose, status)
  values (p_equipment_id, auth.uid(), p_purpose, 'pending')
  returning * into v_req;

  insert into audit_logs (user_id, action, module, record_id, description)
  values (auth.uid(), 'SUBMITTED', 'Borrowing', v_req.id::text,
          'Submitted borrowing request for equipment ' || p_equipment_id::text);

  return v_req;
end;
$$;

-- 6.2 Admin only: approve or reject a pending request
create or replace function review_request(p_request_id uuid, p_decision request_status, p_reason text default null)
returns borrowing_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req  borrowing_requests;
  v_role user_role;
begin
  select role into v_role from profiles where id = auth.uid();

  -- BR-A4-03: only Administrator may approve or reject
  if v_role <> 'admin' then
    raise exception 'BR-A4-03: only an Administrator may approve or reject requests';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'Invalid decision: %', p_decision;
  end if;

  select * into v_req from borrowing_requests where id = p_request_id for update;
  if v_req is null then
    raise exception 'Request not found';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'Only pending requests can be reviewed (current status: %)', v_req.status;
  end if;

  -- BR-A4-02: cannot approve/reject your own request
  if v_req.requester_id = auth.uid() then
    raise exception 'BR-A4-02: you cannot approve or reject your own request';
  end if;

  update borrowing_requests
    set status = p_decision,
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        rejection_reason = case when p_decision = 'rejected' then p_reason else null end
    where id = p_request_id
    returning * into v_req;

  insert into audit_logs (user_id, action, module, record_id, description)
  values (auth.uid(), upper(p_decision::text), 'Borrowing', p_request_id::text,
          'Request ' || p_decision::text || ' for equipment ' || v_req.equipment_id::text);

  return v_req;
end;
$$;

-- 6.3 Admin or Staff: release approved equipment to the borrower
create or replace function release_request(p_request_id uuid)
returns borrowing_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req  borrowing_requests;
  v_role user_role;
begin
  select role into v_role from profiles where id = auth.uid();
  if v_role not in ('admin', 'staff') then
    raise exception 'Only an Administrator or Laboratory Staff may release equipment';
  end if;

  select * into v_req from borrowing_requests where id = p_request_id for update;
  if v_req is null then
    raise exception 'Request not found';
  end if;

  -- BR-A4-04 / BR-A4-07: only Approved requests may be released, rejected cannot
  if v_req.status <> 'approved' then
    raise exception 'BR-A4-04/BR-A4-07: only an Approved request may be released (current status: %)', v_req.status;
  end if;

  update borrowing_requests
    set status = 'released',
        released_by = auth.uid(),
        released_at = now(),
        due_at = now() + interval '7 days'
    where id = p_request_id
    returning * into v_req;

  -- BR-A4-05: released equipment becomes Borrowed
  update equipment set status = 'borrowed', updated_at = now() where id = v_req.equipment_id;

  insert into audit_logs (user_id, action, module, record_id, description)
  values (auth.uid(), 'RELEASED', 'Borrowing', p_request_id::text,
          'Released equipment ' || v_req.equipment_id::text || ' to borrower');

  return v_req;
end;
$$;

-- 6.4 Admin or Staff: process a return
create or replace function return_request(p_request_id uuid, p_condition item_condition, p_notes text default null)
returns borrowing_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req  borrowing_requests;
  v_role user_role;
begin
  select role into v_role from profiles where id = auth.uid();
  if v_role not in ('admin', 'staff') then
    raise exception 'Only an Administrator or Laboratory Staff may process returns';
  end if;

  select * into v_req from borrowing_requests where id = p_request_id for update;
  if v_req is null then
    raise exception 'Request not found';
  end if;

  -- BR-A4-08: returned transactions cannot be processed twice
  if v_req.status not in ('released', 'overdue') then
    raise exception 'BR-A4-08: only a Released or Overdue transaction may be returned (current status: %)', v_req.status;
  end if;

  update borrowing_requests
    set status = 'returned',
        returned_at = now(),
        received_by = auth.uid(),
        return_condition = p_condition,
        return_notes = p_notes
    where id = p_request_id
    returning * into v_req;

  -- BR-A4-06: returned equipment becomes Available unless damaged
  update equipment
    set status = case when p_condition = 'damaged' then 'damaged' else 'available' end,
        updated_at = now()
    where id = v_req.equipment_id;

  insert into audit_logs (user_id, action, module, record_id, description)
  values (auth.uid(), 'RETURNED', 'Borrowing', p_request_id::text,
          'Returned equipment ' || v_req.equipment_id::text || ' (' || p_condition::text || ')');

  return v_req;
end;
$$;

-- 6.5 Admin only: close a returned transaction
create or replace function close_request(p_request_id uuid)
returns borrowing_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req  borrowing_requests;
  v_role user_role;
begin
  select role into v_role from profiles where id = auth.uid();
  if v_role <> 'admin' then
    raise exception 'Only an Administrator may close a transaction';
  end if;

  select * into v_req from borrowing_requests where id = p_request_id for update;
  if v_req is null then
    raise exception 'Request not found';
  end if;
  if v_req.status <> 'returned' then
    raise exception 'Only a Returned transaction may be closed (current status: %)', v_req.status;
  end if;

  update borrowing_requests set status = 'closed', closed_at = now()
    where id = p_request_id
    returning * into v_req;

  insert into audit_logs (user_id, action, module, record_id, description)
  values (auth.uid(), 'CLOSED', 'Borrowing', p_request_id::text,
          'Closed transaction for equipment ' || v_req.equipment_id::text);

  return v_req;
end;
$$;

-- 6.6 Scheduled/manual: flip overdue released loans (call from a
--     Supabase cron job, or a button on the Admin dashboard)
create or replace function mark_overdue_requests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update borrowing_requests
    set status = 'overdue'
    where status = 'released' and due_at < now();
  get diagnostics v_count = row_count;

  if v_count > 0 then
    insert into audit_logs (user_id, action, module, record_id, description)
    values (auth.uid(), 'OVERDUE_SWEEP', 'Borrowing', null, v_count || ' request(s) marked overdue');
  end if;

  return v_count;
end;
$$;

-- 6.7 Admin or Staff: add equipment
create or replace function admin_add_equipment(p_code text, p_name text, p_category text, p_description text)
returns equipment
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role user_role;
  v_eq   equipment;
begin
  select role into v_role from profiles where id = auth.uid();
  if v_role not in ('admin', 'staff') then
    raise exception 'Only an Administrator or Laboratory Staff may add equipment';
  end if;

  insert into equipment (code, name, category, description, status, created_by)
  values (p_code, p_name, p_category, p_description, 'available', auth.uid())
  returning * into v_eq;

  insert into audit_logs (user_id, action, module, record_id, description)
  values (auth.uid(), 'CREATED', 'Equipment', v_eq.id::text, 'Added equipment ' || p_code);

  return v_eq;
end;
$$;

-- 6.8 Admin or Staff: submit equipment for maintenance
create or replace function set_equipment_maintenance(p_equipment_id uuid, p_notes text default null)
returns equipment
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role user_role;
  v_eq   equipment;
begin
  select role into v_role from profiles where id = auth.uid();
  if v_role not in ('admin', 'staff') then
    raise exception 'Only an Administrator or Laboratory Staff may submit a maintenance request';
  end if;

  update equipment set status = 'maintenance', updated_at = now()
    where id = p_equipment_id
    returning * into v_eq;

  insert into audit_logs (user_id, action, module, record_id, description)
  values (auth.uid(), 'MAINTENANCE_REQUESTED', 'Equipment', p_equipment_id::text,
          coalesce(p_notes, 'Submitted for maintenance'));

  return v_eq;
end;
$$;

-- 6.9 Admin only: mark equipment available again after maintenance
create or replace function set_equipment_available(p_equipment_id uuid)
returns equipment
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role user_role;
  v_eq   equipment;
begin
  select role into v_role from profiles where id = auth.uid();
  if v_role <> 'admin' then
    raise exception 'Only an Administrator may close out a maintenance record';
  end if;

  update equipment set status = 'available', updated_at = now()
    where id = p_equipment_id
    returning * into v_eq;

  insert into audit_logs (user_id, action, module, record_id, description)
  values (auth.uid(), 'MAINTENANCE_COMPLETED', 'Equipment', p_equipment_id::text,
          'Marked equipment available after maintenance');

  return v_eq;
end;
$$;

-- 6.10 Admin only: change a user's role
create or replace function admin_set_user_role(p_user_id uuid, p_role user_role)
returns profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role user_role;
  v_prof profiles;
begin
  select role into v_role from profiles where id = auth.uid();
  if v_role <> 'admin' then
    raise exception 'Only an Administrator may manage user roles';
  end if;

  update profiles set role = p_role where id = p_user_id returning * into v_prof;

  insert into audit_logs (user_id, action, module, record_id, description)
  values (auth.uid(), 'ROLE_CHANGED', 'Users', p_user_id::text, 'Set role to ' || p_role::text);

  return v_prof;
end;
$$;

-- =====================================================================
-- End of schema.sql
-- =====================================================================
