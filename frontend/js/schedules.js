// schedules.js
let allParcels = [];

document.addEventListener("DOMContentLoaded", async () => {
    await Promise.all([loadFarmerOptions(), loadCanalOptions(), loadAllParcels()]);
    setDefaultTimes();
    loadSchedules();
});

function setDefaultTimes() {
    const now = new Date();
    const start = new Date(now.getTime() + 24 * 60 * 60 * 1000); // tomorrow
    start.setMinutes(0, 0, 0);
    const end = new Date(start.getTime() + 2 * 60 * 60 * 1000); // +2 hours
    document.getElementById("s-start").value = toDatetimeLocalValue(start);
    document.getElementById("s-end").value = toDatetimeLocalValue(end);
}

async function loadFarmerOptions() {
    const res = await api.get("/farmers");
    const sel = document.getElementById("s-farmer-id");
    sel.innerHTML = `<option value="">Select farmer...</option>` +
        res.data.filter((f) => f.status === "ACTIVE").map((f) => `<option value="${f.farmer_id}">${f.name} (#${f.farmer_id})</option>`).join("");
}

async function loadCanalOptions() {
    const res = await api.get("/canals");
    const sel = document.getElementById("s-canal-id");
    sel.innerHTML = `<option value="">Select canal...</option>` +
        res.data.map((c) => `<option value="${c.canal_id}" ${c.status !== "ACTIVE" ? "disabled" : ""}>${c.canal_name}${c.status !== "ACTIVE" ? " (" + c.status + ")" : ""}</option>`).join("");
}

async function loadAllParcels() {
    const res = await api.get("/parcels");
    allParcels = res.data;
}

function onFarmerChange() {
    const farmerId = document.getElementById("s-farmer-id").value;
    const sel = document.getElementById("s-parcel-id");
    const parcels = allParcels.filter((p) => String(p.farmer_id) === String(farmerId) && p.status === "ACTIVE");
    sel.innerHTML = `<option value="">Select parcel...</option>` +
        parcels.map((p) => `<option value="${p.parcel_id}">${p.location} (${p.area_acres} ac, ${p.crop_name})</option>`).join("");
    document.getElementById("s-crop-display").value = "";
    document.getElementById("s-suggested").textContent = "-";
}

async function onParcelChange() {
    const parcelId = document.getElementById("s-parcel-id").value;
    if (!parcelId) return;
    try {
        const res = await api.get(`/parcels/${parcelId}`);
        const p = res.data;
        document.getElementById("s-crop-display").value = p.crop_name;
        document.getElementById("s-suggested").textContent = formatLitres(p.required_water_litres);
        if (!document.getElementById("s-water").value) {
            document.getElementById("s-water").value = p.required_water_litres;
        }
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function collectFormPayload() {
    return {
        farmer_id: document.getElementById("s-farmer-id").value,
        parcel_id: document.getElementById("s-parcel-id").value,
        canal_id: document.getElementById("s-canal-id").value,
        start_time: document.getElementById("s-start").value,
        end_time: document.getElementById("s-end").value,
        requested_water: document.getElementById("s-water").value,
    };
}

function validatePayload(payload) {
    if (!payload.farmer_id || !payload.parcel_id || !payload.canal_id || !payload.start_time || !payload.end_time || !payload.requested_water) {
        return "Please fill in every field before checking availability.";
    }
    return null;
}

async function checkAvailability() {
    const payload = collectFormPayload();
    const err = validatePayload(payload);
    const resultBox = document.getElementById("check-result");
    if (err) {
        resultBox.innerHTML = `<div class="check-result bad">${err}</div>`;
        return;
    }
    resultBox.innerHTML = `<div class="check-result">Checking...</div>`;
    try {
        const res = await api.post("/schedules/check", payload);
        const ok = res.data.status === "APPROVED";
        resultBox.innerHTML = `<div class="check-result ${ok ? "ok" : "bad"}">
            ${ok ? "&#10003; " : "&#10007; "} ${res.data.message}
        </div>`;
    } catch (e) {
        resultBox.innerHTML = `<div class="check-result bad">${e.message}</div>`;
    }
}

async function submitSchedule() {
    const payload = collectFormPayload();
    const err = validatePayload(payload);
    if (err) {
        showAlert("alert-box", err);
        return;
    }
    try {
        const res = await api.post("/schedules", payload);
        showAlert("alert-box", res.message, "success");
        document.getElementById("check-result").innerHTML = "";
        loadSchedules();
    } catch (e) {
        showAlert("alert-box", e.message);
    }
}

async function loadSchedules() {
    const status = document.getElementById("filter-status").value;
    const tbody = document.getElementById("schedules-tbody");
    tbody.innerHTML = `<tr><td colspan="10">Loading...</td></tr>`;
    try {
        const path = status ? `/schedules?status=${encodeURIComponent(status)}` : "/schedules";
        const res = await api.get(path);
        renderSchedulesTable(res.data);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderSchedulesTable(rows) {
    const tbody = document.getElementById("schedules-tbody");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="10">No schedules found.</td></tr>`;
        return;
    }
    tbody.innerHTML = rows.map((s) => `
        <tr>
            <td>${s.schedule_id}</td>
            <td>${s.farmer_name}</td>
            <td>${s.crop_name}</td>
            <td>${s.canal_name}</td>
            <td>${formatDateTime(s.start_time)}</td>
            <td>${formatDateTime(s.end_time)}</td>
            <td>${formatLitres(s.requested_water)}</td>
            <td>${formatLitres(s.approved_water)}</td>
            <td>${badgeHtml(s.status)}</td>
            <td class="actions-cell">
                ${s.status === "APPROVED" ? `<button class="btn btn-sm btn-outline-success" onclick="markCompleted(${s.schedule_id})">Mark Completed</button>` : ""}
                ${(s.status === "PENDING" || s.status === "APPROVED") ? `<button class="btn btn-sm btn-outline-danger" onclick="cancelSchedule(${s.schedule_id})">Cancel</button>` : ""}
            </td>
        </tr>
    `).join("");
}

async function markCompleted(scheduleId) {
    try {
        await api.put(`/schedules/${scheduleId}`, { status: "COMPLETED" });
        loadSchedules();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function cancelSchedule(scheduleId) {
    if (!confirm("Cancel this schedule?")) return;
    try {
        await api.put(`/schedules/${scheduleId}`, { status: "CANCELLED" });
        loadSchedules();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}
