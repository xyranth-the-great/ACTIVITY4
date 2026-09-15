# Business Rules

| ID | Rule | Where it's enforced |
|----|------|----------------------|
| BR-A4-01 | Only available equipment may be requested. | `submit_borrow_request()` checks `equipment.status = 'available'` before inserting; raises otherwise. |
| BR-A4-02 | Staff/Admin cannot approve their own request. | `review_request()` compares `requester_id` to `auth.uid()` and refuses if they match. |
| BR-A4-03 | Only Administrator may approve or reject requests. | `review_request()` reads the caller's role from `profiles` and refuses unless `role = 'admin'`. |
| BR-A4-04 | Only Approved requests may be released. | `release_request()` refuses unless `status = 'approved'`. |
| BR-A4-05 | Released equipment becomes Borrowed. | `release_request()` sets `equipment.status = 'borrowed'` in the same transaction as the release. |
| BR-A4-06 | Returned equipment becomes Available unless damaged. | `return_request()` sets `equipment.status` to `'available'` or `'damaged'` based on the reported condition. |
| BR-A4-07 | Rejected requests cannot be released. | Same guard as BR-A4-04 — `release_request()` only accepts `status = 'approved'`, so `rejected` is never eligible. |
| BR-A4-08 | Returned transactions cannot be processed twice. | `return_request()` only accepts `status IN ('released','overdue')`; once `returned`, a second call raises an exception. |
| BR-A4-09 | Equipment under Maintenance cannot be borrowed. | Same check as BR-A4-01 — `submit_borrow_request()` requires `status = 'available'`, which excludes `maintenance`. |
| BR-A4-10 | Sensitive operations must be logged. | Every RPC function (`submit_borrow_request`, `review_request`, `release_request`, `return_request`, `close_request`, equipment/user management functions) inserts into `audit_logs` in the same transaction as the state change, so a log entry can never be skipped. |

All ten rules live inside `SECURITY DEFINER` PostgreSQL functions
(`sql/schema.sql`, section 6) rather than only in client-side JavaScript.
The web app calls these functions through `supabase.rpc(...)` and never
writes to `borrowing_requests` or `audit_logs` directly — there is no RLS
`insert`/`update` policy on either table, so even a hand-crafted API
request from outside the app cannot bypass a rule.
