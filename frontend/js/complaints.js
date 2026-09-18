// complaints.js
document.addEventListener("DOMContentLoaded", async () => {
    await loadFarmerOptions();
    loadComplaints();
});

async function loadFarmerOptions() {
    const res = await api.get("/farmers");
    document.getElementById("co-farmer-id").innerHTML = `<option value="">Select farmer...</option>` +
        res.data.map((f) => `<option value="${f.farmer_id}">${f.name} (#${f.farmer_id})</option>`).join("");
    document.getElementById("co-farmer-id").addEventListener("change", loadFarmerSchedules);
}

async function loadFarmerSchedules() {
    const farmerId = document.getElementById("co-farmer-id").value;
    const sel = document.getElementById("co-schedule-id");
    if (!farmerId) {
        sel.innerHTML = `<option value="">None</option>`;
        return;
    }
    try {
        const res = await api.get(`/schedules?farmer_id=${farmerId}`);
        sel.innerHTML = `<option value="">None</option>` +
            res.data.map((s) => `<option value="${s.schedule_id}">#${s.schedule_id} - ${s.canal_name} (${formatDateTime(s.start_time)})</option>`).join("");
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function submitComplaint() {
    const payload = {
        farmer_id: document.getElementById("co-farmer-id").value,
        schedule_id: document.getElementById("co-schedule-id").value || null,
        complaint_type: document.getElementById("co-type").value,
        description: document.getElementById("co-description").value.trim(),
    };
    if (!payload.farmer_id || !payload.description) {
        showAlert("alert-box", "Farmer and description are required.");
        return;
    }
    try {
        const res = await api.post("/complaints", payload);
        showAlert("alert-box", res.message, "success");
        document.getElementById("co-description").value = "";
        loadComplaints();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function loadComplaints() {
    const status = document.getElementById("filter-complaint-status").value;
    const tbody = document.getElementById("complaints-tbody");
    tbody.innerHTML = `<tr><td colspan="7">Loading...</td></tr>`;
    try {
        const path = status ? `/complaints?status=${encodeURIComponent(status)}` : "/complaints";
        const res = await api.get(path);
        renderComplaintsTable(res.data);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderComplaintsTable(rows) {
    const tbody = document.getElementById("complaints-tbody");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="7">No complaints found.</td></tr>`;
        return;
    }
    tbody.innerHTML = rows.map((c) => `
        <tr>
            <td>${c.complaint_id}</td>
            <td>${c.farmer_name}</td>
            <td>${c.complaint_type.replaceAll("_", " ")}</td>
            <td>${c.description}</td>
            <td>${badgeHtml(c.status)}</td>
            <td>${formatDateTime(c.created_at)}</td>
            <td class="actions-cell">
                ${c.status !== "RESOLVED" && c.status !== "REJECTED" ? `
                    <select class="form-select form-select-sm d-inline-block" style="width:auto;" onchange="updateComplaintStatus(${c.complaint_id}, this.value)">
                        <option value="">Update status...</option>
                        <option value="IN_PROGRESS">In Progress</option>
                        <option value="RESOLVED">Resolved</option>
                        <option value="REJECTED">Rejected</option>
                    </select>` : ""}
            </td>
        </tr>
    `).join("");
}

async function updateComplaintStatus(complaintId, status) {
    if (!status) return;
    try {
        await api.put(`/complaints/${complaintId}`, { status });
        loadComplaints();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}
