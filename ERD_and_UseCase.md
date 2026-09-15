# Updated ERD and Use Case Diagram

Both diagrams are written in Mermaid, which GitHub renders automatically
when this file is viewed in the repository.

## Entity Relationship Diagram

```mermaid
erDiagram
    PROFILES ||--o{ BORROWING_REQUESTS : "submits (requester_id)"
    PROFILES ||--o{ BORROWING_REQUESTS : "reviews (reviewed_by)"
    PROFILES ||--o{ BORROWING_REQUESTS : "releases (released_by)"
    PROFILES ||--o{ BORROWING_REQUESTS : "receives (received_by)"
    PROFILES ||--o{ EQUIPMENT : "adds (created_by)"
    PROFILES ||--o{ AUDIT_LOGS : "performs (user_id)"
    EQUIPMENT ||--o{ BORROWING_REQUESTS : "is requested in"

    PROFILES {
        uuid id PK
        text full_name
        text email
        enum role "admin | staff | requester"
        timestamptz created_at
    }

    EQUIPMENT {
        uuid id PK
        text code UK
        text name
        text category
        text description
        enum status "available|borrowed|maintenance|damaged|retired"
        uuid created_by FK
        timestamptz created_at
        timestamptz updated_at
    }

    BORROWING_REQUESTS {
        uuid id PK
        uuid equipment_id FK
        uuid requester_id FK
        text purpose
        enum status "pending|approved|rejected|released|returned|overdue|closed"
        timestamptz requested_at
        uuid reviewed_by FK
        timestamptz reviewed_at
        text rejection_reason
        uuid released_by FK
        timestamptz released_at
        timestamptz due_at
        timestamptz returned_at
        uuid received_by FK
        enum return_condition "good|damaged"
        text return_notes
        timestamptz closed_at
    }

    AUDIT_LOGS {
        uuid id PK
        uuid user_id FK
        text action
        text module
        text record_id
        text description
        timestamptz created_at
    }
```

## Use Case Diagram

```mermaid
flowchart LR
    Requester(["Requester / Viewer"])
    Staff(["Laboratory Staff"])
    Admin(["Administrator"])

    subgraph System["Laboratory Asset & Service Management System"]
        UC1(View equipment)
        UC2(Submit borrowing request)
        UC3(View own request history)
        UC4(Create borrowing transaction)
        UC5(Process return)
        UC6(Submit maintenance request)
        UC7(Update permitted records)
        UC8(Manage users)
        UC9(Approve / reject request)
        UC10(Release equipment)
        UC11(Manage maintenance)
        UC12(View reports)
        UC13(View audit logs)
    end

    Requester --> UC1
    Requester --> UC2
    Requester --> UC3

    Staff --> UC1
    Staff --> UC4
    Staff --> UC5
    Staff --> UC6
    Staff --> UC7
    Staff --> UC10

    Admin --> UC1
    Admin --> UC8
    Admin --> UC9
    Admin --> UC10
    Admin --> UC11
    Admin --> UC12
    Admin --> UC13

    UC2 -.include.-> UC1
    UC9 -.include.-> UC13
    UC10 -.include.-> UC13
    UC5 -.include.-> UC13
```
