# Laboratory 4-A — Role-Based Asset Transaction and Approval Management

A GitHub Pages front end (plain HTML/CSS/JS + the Supabase JS client) on
top of a Supabase Postgres backend. All authorization — roles, the
approval workflow, business rules, and the audit trail — is enforced in
the database (Row Level Security + `SECURITY DEFINER` functions), and
mirrored in the UI so people never see controls they can't use.

## 1. Create the Supabase project

1. Go to [supabase.com](https://supabase.com) → New project. Note the
   **Project URL** and **anon public key** (Settings → API).
2. Settings → Authentication → Providers → Email: for a quick classroom
   demo you can turn **off** "Confirm email" so new accounts can sign in
   immediately. Leave it on if you want the confirmation-email flow.
3. Open the **SQL Editor** and run, in order:
   - `sql/schema.sql` — tables, enums, RLS policies, RPC functions, and
     the `handle_new_user` trigger.
   - `sql/seed.sql` — sample equipment rows (optional but recommended for
     testing/screenshots).

## 2. Point the app at your project

Edit `js/config.js`:

```js
export const SUPABASE_URL = "https://YOUR-PROJECT-REF.supabase.co";
export const SUPABASE_ANON_KEY = "YOUR-ANON-PUBLIC-KEY";
```

The anon key is meant to be public — every table it touches is locked
down by the RLS policies in `sql/schema.sql`.

## 3. Create your first Administrator

New accounts always start as **Requester** (see `handle_new_user()` in
the schema) — this stops a self-registering stranger from granting
themselves Admin. Bootstrap your own Admin once:

1. Open the deployed site (or `index.html` locally) → **Create account**
   → sign up normally.
2. In the Supabase SQL Editor:
   ```sql
   update profiles set role = 'admin' where email = 'you@example.com';
   ```
3. Sign back in. You now see the **Users** and **Audit Log** pages, and
   can promote any other account from the **Users** page from now on —
   no more manual SQL needed.

## 4. Run locally / deploy to GitHub Pages

No build step — it's static HTML/CSS/JS.

- **Locally:** serve the folder with any static server, e.g.
  `python3 -m http.server 8080`, then open `http://localhost:8080`.
  (Opening `index.html` directly via `file://` will not work — ES module
  imports require an HTTP origin.)
- **GitHub Pages:** push this folder to a repo, then Settings → Pages →
  Deploy from branch → pick the branch/root. Your live URL will be
  `https://<username>.github.io/<repo>/`.

## Project structure

```
index.html          Login
register.html        Sign up (always creates a Requester)
dashboard.html        Role-based overview
equipment.html         Inventory, borrow requests, maintenance actions
requests.html           The approval workflow: approve/reject/release/return
users.html                Administrator only — role management
audit.html                 Administrator only — audit trail
css/styles.css        Design system
js/
  config.js            Supabase URL/key (edit this)
  supabaseClient.js      Supabase client instance
  auth.js                  Session + role route guards
  nav.js                     Role-based sidebar
  ui.js                        Toasts, modals, formatting helpers
sql/
  schema.sql             Tables, RLS, RPC functions (run first)
  seed.sql                  Sample equipment + admin bootstrap note
docs/
  role_permission_matrix.md
  business_rules.md
  workflow_diagram.md
  ERD_and_UseCase.md
  test_plan.md
```

## How authorization is enforced at both levels

- **Interface level:** `js/auth.js#requireAuth(allowedRoles)` runs at the
  top of every page, redirecting to login if there's no session and to
  the dashboard (with a denied banner) if the role doesn't match.
  `js/nav.js` also only renders links a role is allowed to use.
- **Database level:** every write to `borrowing_requests`, `audit_logs`,
  and user roles goes through a `SECURITY DEFINER` PL/pgSQL function
  (`sql/schema.sql`, section 6) that independently re-checks the caller's
  role and the record's current state, and RLS policies block any direct
  table write that tries to skip those functions.

See `docs/business_rules.md` for exactly where each BR-A4-xx rule lives,
and `docs/role_permission_matrix.md` for the full role/action matrix.

## Submission checklist

1. GitHub repository URL — your fork/push of this project.
2. Live GitHub Pages URL — from step 4 above.
3. Updated ERD and Use Case Diagram — `docs/ERD_and_UseCase.md`.
4. Role-permission matrix — `docs/role_permission_matrix.md`.
5. Workflow diagram — `docs/workflow_diagram.md`.
6. Business rules — `docs/business_rules.md`.
7. Audit-log screenshot — take one from `audit.html` after running a few
   workflow actions.
8. Functional test results — fill in `docs/test_plan.md`.
