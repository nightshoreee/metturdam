# Test Cases

These can be run either through the frontend UI or directly against the
API with `curl` / Postman. "Expected" describes the observable result.

| # | Test | Steps | Expected |
|---|---|---|---|
| 1 | Valid water booking | POST `/api/schedules` with a free canal/time slot within dam & canal capacity | 201, `status: APPROVED`, schedule row created, dam `available_water` reduced |
| 2 | Overlapping canal booking | Book a canal/time slot, then POST another request for the same canal with an overlapping time | 409, message starts with "SLOT CONFLICT", no new row inserted |
| 3 | Insufficient dam water | POST a request with `requested_water` far larger than current `available_water` | 409, "INSUFFICIENT DAM WATER" |
| 4 | Inactive canal | POST a request targeting a canal with `status = 'MAINTENANCE'` or `'INACTIVE'` | 409/REJECTED, "Canal is not active" |
| 5 | Invalid time range | POST a request where `end_time <= start_time` | 400/REJECTED, "Invalid time range" |
| 6 | Canal capacity exceeded | POST a request whose `requested_water` exceeds `capacity_litres_per_hour x duration_hours` | REJECTED, "CANAL CAPACITY EXCEEDED" |
| 7 | Parcel/farmer mismatch | POST a request with a `parcel_id` that belongs to a different farmer | REJECTED, "does not belong to the specified farmer" |
| 8 | Valid water usage | POST `/api/usage` with `schedule_id` + `measured_water` for an approved schedule | 201, and a Bill is auto-created/updated (check `/api/bills?farmer_id=`) |
| 9 | Multiple usage readings sum correctly | POST two `/api/usage` rows for the same schedule | The bill's `water_used`/`total_amount` reflect the SUM of both readings, not just the latest one |
| 10 | Payment update | POST `/api/payments` for the full outstanding amount on a bill | Bill `status` becomes `PAID` |
| 11 | Partial payment | POST `/api/payments` for less than the bill total | Bill `status` remains `UNPAID`; `amount_paid` in `vw_billing_report` increases |
| 12 | Manual bill regeneration | POST `/api/bills/generate/<schedule_id>` | Bill recomputed from current `Water_Usage` sum via `sp_generate_bill` |
| 13 | Complaint submission | POST `/api/complaints` with a valid `farmer_id` | 201, status `OPEN` |
| 14 | Complaint resolution | PUT `/api/complaints/<id>` with `status: RESOLVED` | `resolved_at` is stamped with the current time |
| 15 | Farmer deactivation | DELETE `/api/farmers/<id>` | Farmer `status` becomes `INACTIVE` (row is NOT removed -- history stays intact) |
| 16 | Duplicate farmer phone | POST `/api/farmers` with a phone number already in use | 409, uniqueness-violation message |
| 17 | Crop still referenced | DELETE `/api/crops/<id>` for a crop used by an existing Land_Parcel | 409, "still referenced by land parcels" |
| 18 | Crop-based water requirement | GET `/api/parcels/<id>` | `required_water_litres` equals `area_acres * water_requirement_per_acre` exactly |
| 19 | Scheduled vs actual comparison | GET `/api/usage/compare/<schedule_id>` after recording usage | Correct `SAVED`/`OVERUSE`/`EXACT` classification and `difference` value |
| 20 | Transaction rollback | Run the manual ROLLBACK block in `08_sample_transactions.sql` | The `SELECT COUNT(*)` afterward returns `0` -- the row was never persisted |
| 21 | Missing required fields | POST `/api/farmers` with no `phone` | 400, "Missing required fields: phone" |
| 22 | Report endpoints return data | GET each of the 10 `/api/reports/...` endpoints | Each returns `success: true` with an array in `data` |

## How these map to the killer features
- Tests 2, 4, 6, 7 -> KILLER FEATURE 1 (conflict/validation)
- Test 18 -> KILLER FEATURE 2 (crop-based water requirement)
- Test 3 -> KILLER FEATURE 3 (dam availability)
- Tests 8, 9, 12 -> KILLER FEATURE 4 (automatic billing)
- Test 19 -> KILLER FEATURE 5 (usage monitoring)
- Tests 13, 14 -> KILLER FEATURE 6 (complaint management)
