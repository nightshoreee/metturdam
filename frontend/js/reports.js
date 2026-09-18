// reports.js -- one tab per report; each report defines its API path,
// its own table columns, and how to format each column.
const REPORTS = [
    { key: "water-by-farmer", label: "Water by Farmer", path: "/reports/water-by-farmer",
      cols: [["farmer_id", "ID"], ["name", "Farmer"], ["total_water_used", "litres:Total Water Used"]] },
    { key: "water-by-canal", label: "Water by Canal", path: "/reports/water-by-canal",
      cols: [["canal_id", "ID"], ["canal_name", "Canal"], ["total_water_used", "litres:Total Water Used"]] },
    { key: "top-crops", label: "Highest Water-Consuming Crops", path: "/reports/top-crops",
      cols: [["crop_id", "ID"], ["crop_name", "Crop"], ["total_water_used", "litres:Total Water Used"]] },
    { key: "unpaid-farmers", label: "Farmers with Unpaid Bills", path: "/reports/unpaid-farmers",
      cols: [["farmer_id", "ID"], ["name", "Farmer"], ["phone", "Phone"], ["unpaid_bills", "Unpaid Bills"], ["total_due", "currency:Total Due"]] },
    { key: "daily-allocation", label: "Daily Water Allocation", path: "/reports/daily-allocation",
      cols: [["allocation_date", "date:Date"], ["schedule_count", "Schedules"], ["total_allocated", "litres:Total Allocated"]] },
    { key: "canal-utilization", label: "Canal Utilization", path: "/reports/canal-utilization",
      cols: [["canal_name", "Canal"], ["status", "status:Status"], ["total_schedules", "Total Schedules"], ["total_allocated_litres", "litres:Total Allocated"]] },
    { key: "usage-vs-scheduled", label: "Usage vs Scheduled", path: "/reports/usage-vs-scheduled",
      cols: [["schedule_id", "ID"], ["farmer_name", "Farmer"], ["scheduled_water", "litres:Scheduled"], ["actual_water", "litres:Actual"], ["difference", "litres:Difference"]] },
    { key: "dam-availability", label: "Current Dam Availability", path: "/reports/dam-availability",
      cols: [["water_level", "Level (m)"], ["available_water", "litres:Available Water"], ["release_rate", "litres:Release Rate"], ["recorded_at", "datetime:Recorded At"]] },
    { key: "complaints-by-type", label: "Complaints by Type", path: "/reports/complaints-by-type",
      cols: [["complaint_type", "Type"], ["total", "Total"]] },
    { key: "completed-schedules", label: "Completed Schedules Count", path: "/reports/completed-schedules",
      cols: [["completed_count", "Completed Schedules"]] },
];

let activeReport = null;

document.addEventListener("DOMContentLoaded", () => {
    const tabsEl = document.getElementById("report-tabs");
    tabsEl.innerHTML = REPORTS.map((r) => `<button class="btn btn-outline-primary btn-sm" data-key="${r.key}" onclick="loadReport('${r.key}')">${r.label}</button>`).join("");
    loadReport(REPORTS[0].key);
});

async function loadReport(key) {
    const report = REPORTS.find((r) => r.key === key);
    if (!report) return;
    activeReport = report;

    document.querySelectorAll("#report-tabs button").forEach((b) => b.classList.toggle("btn-primary", b.dataset.key === key));
    document.querySelectorAll("#report-tabs button").forEach((b) => b.classList.toggle("btn-outline-primary", b.dataset.key !== key));

    document.getElementById("report-title").textContent = report.label;
    document.getElementById("report-head").innerHTML = report.cols.map(([, spec]) => `<th>${spec.split(":").pop()}</th>`).join("");
    document.getElementById("report-body").innerHTML = `<tr><td colspan="${report.cols.length}">Loading...</td></tr>`;

    try {
        const res = await api.get(report.path);
        renderReportTable(res.data, report.cols);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderReportTable(rows, cols) {
    const tbody = document.getElementById("report-body");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="${cols.length}">No data.</td></tr>`;
        return;
    }
    tbody.innerHTML = rows.map((row) => {
        const cells = cols.map(([field, spec]) => {
            const kind = spec.includes(":") ? spec.split(":")[0] : "";
            const v = row[field];
            let out = v;
            if (kind === "litres") out = formatLitres(v);
            else if (kind === "currency") out = formatCurrency(v);
            else if (kind === "date") out = formatDate(v);
            else if (kind === "datetime") out = formatDateTime(v);
            else if (kind === "status") out = badgeHtml(v);
            return `<td>${out === null || out === undefined ? "-" : out}</td>`;
        }).join("");
        return `<tr>${cells}</tr>`;
    }).join("");
}
