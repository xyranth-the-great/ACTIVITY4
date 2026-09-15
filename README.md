# Laboratory Asset & Service Management System

**Role-Based Asset Transaction and Approval Management**

A web application for managing laboratory equipment borrowing, built around three
user roles, a five-stage approval workflow, and a full audit trail. Authorization
is enforced twice — once in the interface, once in the database — so the rules
hold even if someone bypasses the UI entirely.

Built for **Systems Analysis and Design, Laboratory 4-A**, on GitHub Pages and
Supabase.

---

## What it does

Laboratories lend equipment — cameras, tools, instruments — to staff and
students. That process needs guardrails: not everyone should be able to approve
their own request, release equipment that was never approved, or return the
same item twice. This system encodes those guardrails directly into the data
layer, not just the screens people see.

- **Three roles** — Administrator, Laboratory Staff, and Requester/Viewer — each
  with a different slice of the interface and a different set of permitted
  actions.
- **A seven-state approval workflow** — every borrowing request moves through
  Pending → Approved/Rejected → Released → Returned/Overdue → Closed, and each
  transition is a single atomic database operation.
- **Ten enforced business rules** — from *"only available equipment may be
  requested"* to *"a returned transaction can never be processed twice"* —
  checked inside the database, not just hinted at in the UI.
- **A complete audit trail** — every sensitive action (approvals, rejections,
  releases, returns, role changes) writes an immutable log entry: who, what,
  when.

## Roles at a glance

| Role | What they see and do |
|---|---|
| **Administrator** | Everything — manages users and their roles, approves or rejects requests, oversees maintenance, and is the only role that can read the audit log and system reports. |
| **Laboratory Staff** | The operational layer — adds and edits equipment, creates and releases borrowing transactions, processes returns, and submits maintenance requests. |
| **Requester / Viewer** | The everyday user — browses available equipment, submits borrowing requests, and tracks their own request history. |

## The approval workflow

```
Submitted → Pending → Administrator Reviews
                          ├─ Approved → Released → Returned → Closed
                          └─ Rejected (dead end — cannot be released)
```

An Administrator can never approve or reject their own request, and equipment
under maintenance is never eligible to be borrowed. Every step in this chain —
including the automatic `Released → Overdue` sweep — is a `SECURITY DEFINER`
Postgres function, so the state machine lives in the database rather than in
scattered client-side checks.

## Why the authorization is doubled

Most of this app's actual logic lives in ten PL/pgSQL functions guarded by Row
Level Security — the front end calls them through `supabase.rpc(...)` and never
writes to the sensitive tables directly:

- **Interface level** — role-aware navigation and page guards mean a Requester
  never even sees an "Approve" button or a link to the Users page.
- **Database level** — Row Level Security policies and the functions
  themselves independently re-check the caller's role and the record's current
  state, so a hand-crafted API call from outside the app is refused the same
  way a stray click in the UI would be.

This means the business rules hold regardless of which layer someone tries to
go through.

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Static HTML, CSS, and vanilla JavaScript (ES modules) |
| Backend | [Supabase](https://supabase.com) — Postgres, Auth, Row Level Security, RPC functions |
| Hosting | GitHub Pages (frontend) + Supabase (backend), no build step |

## Project structure

```
index.html          Login
register.html        Sign-up (new accounts always start as Requester)
dashboard.html         Role-based overview
equipment.html           Inventory, borrow requests, maintenance actions
requests.html              The approval workflow — approve, reject, release, return
users.html                   Administrator-only — role management
audit.html                     Administrator-only — audit trail
css/                              Design system
js/                                 Auth guards, role-based navigation, Supabase client
sql/                                  Schema, RLS policies, RPC functions, seed data
docs/                                   ERD, use case diagram, role-permission matrix,
                                          business rules, workflow diagram, test plan
```

## Documentation

- [`ERD_and_UseCase.md`](ERD_and_UseCase.md) — entity relationship and use case diagrams
- [`role_permission_matrix.md`](role_permission_matrix.md) — the full role/action matrix
- [`workflow_diagram.md`](workflow_diagram.md) — the approval state machine
- [`business_rules.md`](business_rules.md) — all ten business rules and where each is enforced
- [`test_plan.md`](test_plan.md) — functional test cases and results

## Course context

| | |
|---|---|
| Course | Systems Analysis and Design |
| Laboratory | 4-A — Role-Based Asset Transaction and Approval Management |
| Development approach | Incremental / iterative |
| Platform | GitHub + GitHub Pages + Supabase |
