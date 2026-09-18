# API Documentation

Base URL (local development): `http://localhost:5000/api`

All responses are JSON in the shape:
```json
{ "success": true, "message": "...", "data": ... }
```
or, on error:
```json
{ "success": false, "message": "...", "details": "..." }
```

## Health
| Method | Path | Description |
|---|---|---|
| GET | `/api/health` | Service liveness check |

## Farmers
| Method | Path | Description |
|---|---|---|
| GET | `/api/farmers?search=` | List farmers, optional name/village/phone search |
| GET | `/api/farmers/<id>` | Farmer detail + nested parcels, schedules, bills, complaints |
| POST | `/api/farmers` | Create farmer (`name`, `phone`, `village`) |
| PUT | `/api/farmers/<id>` | Update farmer fields |
| DELETE | `/api/farmers/<id>` | Deactivate farmer (soft delete) |

## Land Parcels
| Method | Path | Description |
|---|---|---|
| GET | `/api/parcels?farmer_id=` | List parcels, optional farmer filter |
| GET | `/api/parcels/<id>` | Parcel detail, includes `required_water_litres` |
| POST | `/api/parcels` | Create parcel (`farmer_id`, `crop_id`, `area_acres`, `location`, `soil_type`) |
| PUT | `/api/parcels/<id>` | Update parcel fields |
| DELETE | `/api/parcels/<id>` | Deactivate parcel |

## Crops
| Method | Path | Description |
|---|---|---|
| GET | `/api/crops` | List crops |
| GET | `/api/crops/<id>` | Crop detail |
| POST | `/api/crops` | Create crop |
| PUT | `/api/crops/<id>` | Update crop |
| DELETE | `/api/crops/<id>` | Delete crop (fails with 409 if still referenced by a parcel) |

## Canals
| Method | Path | Description |
|---|---|---|
| GET | `/api/canals` | List canals |
| GET | `/api/canals/<id>` | Canal detail + today's allocations |
| GET | `/api/canals/utilization` | Per-canal schedule count & allocated litres |
| POST | `/api/canals` | Create canal |
| PUT | `/api/canals/<id>` | Update canal |

## Dam Status
| Method | Path | Description |
|---|---|---|
| GET | `/api/dam/status` | Latest dam reading |
| GET | `/api/dam/history?limit=30` | Historical readings, chronological |
| POST | `/api/dam/status` | Log a new reading (`water_level`, `available_water`, `release_rate`) |

## Water Scheduling
| Method | Path | Description |
|---|---|---|
| POST | `/api/schedules/check` | Preview a request without booking it -- returns `APPROVED` or `REJECTED` with the reason (SLOT CONFLICT / INSUFFICIENT DAM WATER / CANAL CAPACITY EXCEEDED / etc.) |
| POST | `/api/schedules` | Book a water request via `sp_request_water` (same checks, actually persisted) |
| GET | `/api/schedules?farmer_id=&status=` | List schedules (from `vw_schedule_details`) |
| PUT | `/api/schedules/<id>` | Update status (`PENDING`/`APPROVED`/`REJECTED`/`COMPLETED`/`CANCELLED`) |

Request body for `/check` and the schedule POST:
```json
{
  "farmer_id": 1, "parcel_id": 1, "canal_id": 2,
  "start_time": "2026-09-01T06:00:00", "end_time": "2026-09-01T08:00:00",
  "requested_water": 5000
}
```

## Water Usage
| Method | Path | Description |
|---|---|---|
| GET | `/api/usage?schedule_id=` | List usage records |
| GET | `/api/usage/compare/<schedule_id>` | Scheduled vs actual water, with SAVED/OVERUSE/EXACT status |
| POST | `/api/usage` | Record usage (`schedule_id`, `measured_water`) -- automatically creates/updates the schedule's bill via trigger |

## Billing
| Method | Path | Description |
|---|---|---|
| GET | `/api/bills?farmer_id=&status=` | List bills (from `vw_billing_report`) |
| GET | `/api/bills/<id>` | Bill detail |
| POST | `/api/bills/generate/<schedule_id>` | Manually (re)generate a bill via `sp_generate_bill` |

## Payments
| Method | Path | Description |
|---|---|---|
| GET | `/api/payments?farmer_id=` | List payments |
| POST | `/api/payments` | Record a payment (`bill_id`, `farmer_id`, `amount_paid`) -- marks the bill PAID once fully covered |

## Complaints
| Method | Path | Description |
|---|---|---|
| GET | `/api/complaints?farmer_id=&status=` | List complaints |
| POST | `/api/complaints` | Submit a complaint (`farmer_id`, `complaint_type`, `description`) |
| PUT | `/api/complaints/<id>` | Update status (auto-stamps `resolved_at` on RESOLVED/REJECTED) |

## Reports
All under `GET /api/reports/...`, no request body:

| Path | Report |
|---|---|
| `/water-by-farmer` | Total water used by each farmer |
| `/water-by-canal` | Total water used by each canal |
| `/top-crops` | Highest water-consuming crops |
| `/unpaid-farmers` | Farmers with unpaid/overdue bills |
| `/daily-allocation` | Daily water allocation |
| `/canal-utilization` | Canal utilization |
| `/usage-vs-scheduled` | Water usage vs scheduled allocation |
| `/dam-availability` | Current dam water availability |
| `/complaints-by-type` | Number of complaints by type |
| `/completed-schedules` | Number of completed irrigation schedules |

## Error Handling
| Status | Meaning |
|---|---|
| 400 | Missing/invalid fields, bad date format, invalid enum value |
| 404 | Referenced record does not exist |
| 405 | Wrong HTTP method for the endpoint |
| 409 | Business-rule conflict (SLOT CONFLICT, duplicate unique value, insufficient water, foreign-key violation on delete) |
| 500 | Database connection failure or unexpected server error |
