# Role-Permission Matrix

Enforced twice for every row below: **UI** — the sidebar and page guards in
`js/nav.js` / `js/auth.js` only show/allow what a role is entitled to.
**Database** — Row Level Security policies and the `SECURITY DEFINER` RPC
functions in `sql/schema.sql` re-check the same rule independently, so a
request forged outside the UI is still refused.

| Function / Action                              | Administrator | Laboratory Staff | Requester / Viewer |
|--------------------------------------------------|:---:|:---:|:---:|
| View available equipment                         | ✅ | ✅ | ✅ |
| Add / edit equipment                              | ✅ | ✅ | ❌ |
| Delete equipment                                  | ✅ | ❌ | ❌ |
| Submit a borrowing request                        | ✅ | ✅ | ✅ |
| View own request status & history                 | ✅ | ✅ | ✅ |
| View **all** requests                             | ✅ | ✅ | ❌ (own only) |
| Approve / reject a request (BR-A4-03)             | ✅ | ❌ | ❌ |
| Release approved equipment (BR-A4-04)             | ✅ | ✅ | ❌ |
| Process a return (BR-A4-06, BR-A4-08)             | ✅ | ✅ | ❌ |
| Close a returned transaction                      | ✅ | ❌ | ❌ |
| Submit equipment for maintenance                  | ✅ | ✅ | ❌ |
| Mark equipment available after maintenance        | ✅ | ❌ | ❌ |
| Manage user accounts / roles                      | ✅ | ❌ | ❌ |
| View audit logs                                   | ✅ | ❌ | ❌ |
| View reports                                      | ✅ | ❌ | ❌ |

### Special case — BR-A4-02 (self-approval block)
Even for an Administrator, `review_request()` refuses to run if
`requester_id = auth.uid()`. This is not a role check — it's a same-row
check — so it is listed here as a note rather than a matrix column:
**no role may approve or reject a request they personally submitted.**

### Navigation visibility (interface level)
| Page              | Administrator | Staff | Requester |
|--------------------|:---:|:---:|:---:|
| Overview (dashboard.html) | ✅ | ✅ | ✅ |
| Equipment (equipment.html) | ✅ | ✅ | ✅ (read + request only) |
| Requests (requests.html)   | ✅ (all) | ✅ (all) | ✅ (own only) |
| Users (users.html)         | ✅ | ❌ redirected | ❌ redirected |
| Audit Log (audit.html)     | ✅ | ❌ redirected | ❌ redirected |
