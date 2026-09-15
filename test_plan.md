# Functional Testing

Fill in **Actual Result**, **Pass/Fail**, and attach a screenshot for each
case before submitting. Steps assume the seed data in `sql/seed.sql` and at
least one account per role (create via `register.html`, then promote with
`admin_set_user_role` / the Users page — see the main `README.md`).

| Test ID | Scenario | Steps in this app | Expected Result | Actual Result | Pass/Fail |
|---|---|---|---|---|---|
| TC-A4-01 | Viewer attempts to open Admin page | Sign in as a Requester → navigate directly to `users.html` (or `audit.html`) | Redirected to `dashboard.html?denied=1`; banner reads "You don't have access." The same query against `profiles`/`audit_logs` is also blocked by RLS if attempted directly. | | |
| TC-A4-02 | Staff submits request | Sign in as Staff (or Requester) → Equipment → Request on an Available item → submit | New row appears in Requests with status **Pending** | | |
| TC-A4-03 | Administrator approves request | Sign in as Admin → Requests → filter Pending → Approve | Status becomes **Approved**; a new row appears in Audit Log with action `APPROVED` | | |
| TC-A4-04 | Administrator rejects request | Sign in as Admin → Requests → Reject a Pending request, optionally give a reason | Status becomes **Rejected**; reason visible in the Notes column | | |
| TC-A4-05 | Attempt to release rejected request | After TC-A4-04, confirm no Release button appears on the Rejected row; optionally call `release_request()` on that ID via the SQL editor | Operation blocked — UI shows no action, and the RPC raises `BR-A4-04/BR-A4-07` | | |
| TC-A4-06 | Release approved equipment | Sign in as Staff/Admin → Requests → Release an Approved row | Status becomes **Released**; the equipment's row on the Equipment page shows **Borrowed** | | |
| TC-A4-07 | Return released equipment | Sign in as Staff/Admin → Requests → Process return → choose Good or Damaged | Status becomes **Returned**; equipment becomes **Available** (Good) or **Damaged** (Damaged) | | |
| TC-A4-08 | Check audit log after approval | Sign in as Admin → Audit Log | The `APPROVED` entry from TC-A4-03 is visible with correct user, timestamp, and description | | |
| TC-A4-09 | Staff attempts restricted delete | Sign in as Staff → Equipment page has no delete control for Staff; direct RPC/table delete on `equipment` is refused by the `equipment_delete` RLS policy (admin-only) | Operation blocked | | |
| TC-A4-10 | Logout and open protected page | Log out via the sidebar → navigate directly to `dashboard.html` | Redirected to `index.html` (login) | | |

## Notes for graders / screenshots
- Screenshot 1: Requester's `equipment.html` with a Request submitted (TC-A4-02).
- Screenshot 2: Admin's `requests.html` showing Approve/Reject in action (TC-A4-03/04).
- Screenshot 3: `audit.html` filtered to the `APPROVED`/`RELEASED`/`RETURNED` actions (TC-A4-08).
- Screenshot 4: `dashboard.html?denied=1` banner after a Requester tries `users.html` (TC-A4-01).
