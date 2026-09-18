# DBMS Concepts Reference (for viva prep)

This file explains the DBMS concepts used in this project in plain
terms, at a level appropriate for a second-year CSE DBMS viva.

## Entities & Attributes
An **entity** is a real-world thing we store data about (Farmer, Crop,
Canal...). Its **attributes** are the properties we record (a Farmer
has a name, phone, village...). In this project, each entity became
one table, and each attribute became one column.

## Primary Keys
A **primary key** uniquely identifies a row in a table. Every table
here uses a surrogate (auto-incrementing integer) primary key, e.g.
`farmer_id`, `schedule_id`. This is simpler and more stable than using
a "natural" key (like `phone`), which can theoretically change.

## Foreign Keys
A **foreign key** is a column in one table that references the primary
key of another table, enforcing that the referenced row must exist.
Example: `Land_Parcels.farmer_id` references `Farmers.farmer_id` --
you cannot insert a parcel for a farmer_id that doesn't exist.

## Cardinality
Describes how many rows on one side of a relationship can relate to how
many on the other. This project is entirely **1-to-many (1:N)**
relationships -- e.g. one Farmer can have many Land_Parcels, but each
Land_Parcel belongs to exactly one Farmer.

## Normalization (1NF, 2NF, 3NF)
**Normalization** is the process of organizing tables to reduce data
redundancy and avoid update anomalies.
- **1NF (First Normal Form):** every column holds a single, atomic
  value; no repeating groups. (E.g., we don't store a comma-separated
  list of a farmer's parcels in one cell -- each parcel is its own row.)
- **2NF (Second Normal Form):** the table is in 1NF, and every
  non-key column depends on the WHOLE primary key, not just part of
  it. Since every table here has a single-column primary key, this is
  automatically satisfied (partial dependency is only possible with
  composite keys).
- **3NF (Third Normal Form):** the table is in 2NF, and no non-key
  column depends on another non-key column (no "transitive"
  dependency). Example: `Water_Schedules` stores `farmer_id` and
  `parcel_id`, but NOT `farmer_name` -- because `farmer_name` depends
  on `farmer_id`, not directly on `schedule_id`. If we stored
  `farmer_name` directly on the schedule, renaming a farmer would
  require updating every one of their schedule rows -- normalization
  avoids that.

## Functional Dependencies
A functional dependency `X -> Y` means: given a value of X, there is
exactly one corresponding value of Y. Example: `crop_id ->
water_requirement_per_acre` (each crop_id maps to exactly one water
requirement). See `database-design.md` for more examples specific to
this schema.

## Transactions & ACID
A **transaction** is a group of SQL statements executed as a single
unit -- either ALL of them succeed (COMMIT) or NONE of them do
(ROLLBACK). ACID stands for:
- **Atomicity:** the transaction is all-or-nothing.
- **Consistency:** the database moves from one valid state to another
  (constraints are never violated even mid-transaction).
- **Isolation:** concurrent transactions don't see each other's
  uncommitted changes.
- **Durability:** once committed, changes survive a crash.

In this project, `sp_request_water` demonstrates this directly: it
inserts a new schedule AND reduces the dam's available water in the
same transaction. If either write fails, `ROLLBACK` undoes both, so
the system never ends up in the inconsistent state of "water was
reserved but no schedule exists" or vice versa.

## Triggers
A **trigger** is a stored routine that runs automatically in response
to an INSERT/UPDATE/DELETE on a table. This project uses
`trg_after_usage_insert` (fires after a usage reading is inserted, and
automatically creates/updates the matching bill) and
`trg_schedule_status_update` (fires after a schedule's status changes,
and finalizes billing due dates on completion).

## Stored Procedures
A **stored procedure** is a named, reusable block of SQL logic stored
in the database itself, which can take parameters (IN) and return
values (OUT). `sp_request_water` and `sp_generate_bill` centralize
business logic in the database layer so it's enforced consistently no
matter what application calls it.

## Views
A **view** is a saved SELECT query that behaves like a virtual table.
Views simplify repeated complex joins (e.g. `vw_schedule_details` joins
4 tables so the API and reports don't have to repeat that JOIN
everywhere) and can also restrict which columns/rows are exposed.

## Indexes
An **index** is an auxiliary data structure (typically a B-tree) that
speeds up lookups on a column, at the cost of extra storage and
slightly slower writes. This project indexes foreign-key columns (used
in every JOIN) and the columns used in the conflict-detection query
(`canal_id`, `start_time`, `end_time`) and dashboard filters
(`status` columns), since those are read far more often than the
underlying tables are written to.

## JOINs
- **INNER JOIN:** returns only rows that match in both tables.
- **LEFT JOIN:** returns all rows from the left table, with NULLs for
  unmatched right-table columns (used e.g. to show all canals even
  ones with zero schedules).

## Constraints
- **NOT NULL:** a column must always have a value.
- **UNIQUE:** no two rows can share the same value in that column.
- **CHECK:** the value must satisfy a boolean expression (e.g.
  `area_acres > 0`).
- **DEFAULT:** a fallback value used when none is supplied on insert.

Together, these push data-validity rules down into the database itself,
so they hold true regardless of which application (or which bug in
that application) is writing to the database.
