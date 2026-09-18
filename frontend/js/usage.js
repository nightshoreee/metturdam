// usage.js
document.addEventListener("DOMContentLoaded", async () => {
    await loadScheduleOptions();
    loadUsage();
});

async function loadScheduleOptions() {
    const res = await api.get("/schedules");
    const options = res.data
        .filter((s) => s.status === "APPROVED" || s.status === "COMPLETED")
        .map((s) => `<option value="${s.schedule_id}">#${s.schedule_id} - ${s.farmer_name} - ${s.canal_name} (${formatDateTime(s.start_time)})</option>`)
        .join("");
    document.getElementById("u-schedule-id").innerHTML = `<option value="">Select schedule...</option>` + options;
    document.getElementById("cmp-schedule-id").innerHTML = `<option value="">Select schedule...</option>` + options;
}

async function recordUsage() {
    const payload = {
        schedule_id: document.getElementById("u-schedule-id").value,
        measured_water: document.getElementById("u-measured").value,
        meter_reading: document.getElementById("u-meter").value || null,
        remarks: document.getElementById("u-remarks").value || null,
    };
    if (!payload.schedule_id || !payload.measured_water) {
        showAlert("alert-box", "Schedule and measured water are required.");
        return;
    }
    try {
        const res = await api.post("/usage", payload);
        showAlert("alert-box", res.message, "success");
        document.getElementById("u-measured").value = "";
        document.getElementById("u-meter").value = "";
        document.getElementById("u-remarks").value = "";
        loadUsage();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function compareSchedule() {
    const scheduleId = document.getElementById("cmp-schedule-id").value;
    const box = document.getElementById("compare-result");
    if (!scheduleId) {
        box.innerHTML = "";
        return;
    }
    try {
        const res = await api.get(`/usage/compare/${scheduleId}`);
        const d = res.data;
        const cls = d.status === "OVERUSE" ? "bad" : "ok";
        box.innerHTML = `<div class="check-result ${cls}">
            Scheduled: ${formatLitres(d.scheduled_water)} &nbsp;|&nbsp; Actual: ${formatLitres(d.actual_water)}
            &nbsp;|&nbsp; ${d.status === "SAVED" ? "Water Saved" : d.status === "OVERUSE" ? "Water Overuse" : "Exact Match"}: ${formatLitres(Math.abs(d.difference))}
        </div>`;
    } catch (err) {
        box.innerHTML = `<div class="check-result bad">${err.message}</div>`;
    }
}

async function loadUsage() {
    const tbody = document.getElementById("usage-tbody");
    tbody.innerHTML = `<tr><td colspan="7">Loading...</td></tr>`;
    try {
        const res = await api.get("/usage");
        renderUsageTable(res.data);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderUsageTable(rows) {
    const tbody = document.getElementById("usage-tbody");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="7">No usage records yet.</td></tr>`;
        return;
    }
    tbody.innerHTML = rows.map((u) => `
        <tr>
            <td>${u.usage_id}</td>
            <td>${u.farmer_name || "-"}</td>
            <td>#${u.schedule_id}</td>
            <td>${formatLitres(u.measured_water)}</td>
            <td>${formatDateTime(u.recorded_at)}</td>
            <td>${u.meter_reading ?? "-"}</td>
            <td>${u.remarks || "-"}</td>
        </tr>
    `).join("");
}
