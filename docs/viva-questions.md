# Viva Questions & Suggested Answers

**Q1. Why did you use surrogate primary keys (auto-increment IDs)
instead of natural keys like phone number?**
Surrogate keys never change even if real-world data does (a farmer
could change their phone number), and they keep every foreign key a
simple integer, which is faster to index and join on.

**Q2. Walk me through what happens, step by step, when a farmer
requests water.**
The frontend calls `POST /api/schedules`, which calls the
`sp_request_water` stored procedure. The procedure validates the
farmer, the parcel ownership, the canal status, and the time range;
then checks for a conflicting booking on the same canal using
interval-overlap logic; then checks the canal's capacity for the
requested duration; then checks the dam's latest `available_water`.
If every check passes, it inserts the new schedule AND a reduced
`Dam_Status` reading inside a single transaction, so both happen
together or neither does.

**Q3. How exactly does the conflict-detection query work?**
`existing_start < new_end AND existing_end > new_start` -- this is the
standard interval-overlap test. It only returns true when the two time
ranges genuinely overlap; two schedules that end exactly when the next
begins do NOT conflict (`09:00-11:00` followed by `11:00-13:00` is
fine).

**Q4. Why is `Dam_Status` a history table instead of a single row?**
So the dashboard can chart the dam's level over time, and so approvals
always read the single most recent row (`ORDER BY recorded_at DESC
LIMIT 1`) rather than overwriting the only record and losing history.

**Q5. What would happen if two farmers submitted a request for the
same canal/time at the exact same instant?**
MySQL's default `REPEATABLE READ` isolation level, combined with the
row locking that happens once the transaction starts writing, prevents
both from succeeding: whichever transaction commits first reserves the
water and the schedule; the second transaction's conflict/availability
check will see the first transaction's committed row (or be blocked
until it commits) and correctly reject as a conflict.

**Q6. Why is billing done with both a trigger AND a stored procedure?**
The trigger (`trg_after_usage_insert`) makes billing automatic and
guarantees it always happens whenever usage is recorded, regardless of
which client inserted the row. The stored procedure
(`sp_generate_bill`) exists so the same computation can also be
triggered on demand (e.g. to re-bill after a correction) without
needing to delete and re-insert a usage row.

**Q7. How do you prevent the automatic-billing trigger from
double-counting when a schedule has multiple usage readings?**
The trigger doesn't just bill the newly-inserted row -- it recomputes
`SUM(measured_water)` across ALL usage rows for that schedule, then
uses `INSERT ... ON DUPLICATE KEY UPDATE` (backed by the
`UNIQUE(schedule_id)` constraint on Bills) to overwrite the bill with
the correct total, however many readings exist.

**Q8. What's the difference between your two triggers, and why don't
they recurse into each other?**
`trg_after_usage_insert` fires on `Water_Usage` and writes to `Bills`.
`trg_schedule_status_update` fires on `Water_Schedules` and also writes
to `Bills`. Neither trigger writes back to the table it fires on
(Water_Usage or Water_Schedules), and neither writes to the other's
source table, so there is no possibility of a trigger chain looping
back on itself.

**Q9. Why is `required_water_litres` not stored as a column?**
It's a derived value (`area_acres * water_requirement_per_acre`).
Storing it would risk it going stale if either source value changes
later (e.g. the crop assigned to a parcel changes). Computing it on
read -- in the view and in the API -- guarantees it's always correct.

**Q10. What does `ON DELETE CASCADE` vs `ON DELETE RESTRICT` mean, and
where did you use each?**
`CASCADE` deletes child rows automatically when the parent is deleted
(used for Farmers -> Land_Parcels, since a parcel has no meaning
without its farmer). `RESTRICT` blocks the delete if child rows still
exist (used for Crops -> Land_Parcels, since deleting a crop that's
still assigned to farmland should be prevented, not silently cascade
and corrupt the parcel's data).

**Q11. How would you scale this system if the number of farmers grew
100x?**
The composite index on `Water_Schedules(canal_id, start_time,
end_time)` already keeps the (most frequent) conflict-detection query
fast at scale. Beyond that: connection pooling in the Flask layer,
read replicas for the reporting endpoints (which are read-heavy and
tolerate slightly stale data), and potentially partitioning
`Water_Usage`/`Dam_Status` by date, since those grow unboundedly over
time while the other tables stay roughly fixed in size.

**Q12. Why Flask instead of a full ORM like SQLAlchemy?**
For a project whose whole point is demonstrating SQL DBMS features
(stored procedures, triggers, raw transaction control), writing
parameterized SQL directly keeps every query and every call to
`sp_request_water`/`sp_generate_bill` visible and explainable, rather
than hidden behind ORM-generated SQL.
