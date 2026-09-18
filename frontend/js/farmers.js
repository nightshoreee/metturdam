// farmers.js
let farmerModal, farmerDetailModal;

document.addEventListener("DOMContentLoaded", () => {
    farmerModal = new bootstrap.Modal(document.getElementById("farmerModal"));
    farmerDetailModal = new bootstrap.Modal(document.getElementById("farmerDetailModal"));
    loadFarmers();
    document.getElementById("search-input").addEventListener("keydown", (e) => {
        if (e.key === "Enter") loadFarmers();
    });
});

async function loadFarmers() {
    const search = document.getElementById("search-input").value.trim();
    const tbody = document.getElementById("farmers-tbody");
    tbody.innerHTML = `<tr><td colspan="7">Loading...</td></tr>`;
    try {
        const path = search ? `/farmers?search=${encodeURIComponent(search)}` : "/farmers";
        const res = await api.get(path);
        renderFarmersTable(res.data);
    } catch (err) {
        showAlert("alert-box", err.message);
        tbody.innerHTML = `<tr><td colspan="7">Failed to load farmers.</td></tr>`;
    }
}

function renderFarmersTable(rows) {
    const tbody = document.getElementById("farmers-tbody");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="7">No farmers found.</td></tr>`;
        return;
    }
    tbody.innerHTML = rows.map((f) => `
        <tr>
            <td>${f.farmer_id}</td>
            <td><a href="#" onclick="viewFarmer(${f.farmer_id}); return false;">${f.name}</a></td>
            <td>${f.phone}</td>
            <td>${f.village}</td>
            <td>${formatDate(f.registration_date)}</td>
            <td>${badgeHtml(f.status)}</td>
            <td class="actions-cell">
                <button class="btn btn-sm btn-outline-secondary" onclick="openEditModal(${f.farmer_id})"><i class="bi bi-pencil"></i></button>
                <button class="btn btn-sm btn-outline-danger" onclick="deactivateFarmer(${f.farmer_id})"><i class="bi bi-slash-circle"></i></button>
            </td>
        </tr>
    `).join("");
}

function openAddModal() {
    document.getElementById("farmerModalTitle").textContent = "Add Farmer";
    document.getElementById("f-farmer-id").value = "";
    document.getElementById("f-name").value = "";
    document.getElementById("f-phone").value = "";
    document.getElementById("f-village").value = "";
    document.getElementById("f-status").value = "ACTIVE";
}

async function openEditModal(farmerId) {
    try {
        const res = await api.get(`/farmers/${farmerId}`);
        const f = res.data;
        document.getElementById("farmerModalTitle").textContent = "Edit Farmer";
        document.getElementById("f-farmer-id").value = f.farmer_id;
        document.getElementById("f-name").value = f.name;
        document.getElementById("f-phone").value = f.phone;
        document.getElementById("f-village").value = f.village;
        document.getElementById("f-status").value = f.status;
        farmerModal.show();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function saveFarmer() {
    const id = document.getElementById("f-farmer-id").value;
    const payload = {
        name: document.getElementById("f-name").value.trim(),
        phone: document.getElementById("f-phone").value.trim(),
        village: document.getElementById("f-village").value.trim(),
        status: document.getElementById("f-status").value,
    };
    if (!payload.name || !payload.phone || !payload.village) {
        showAlert("alert-box", "Name, phone and village are required.");
        return;
    }
    try {
        if (id) {
            await api.put(`/farmers/${id}`, payload);
        } else {
            await api.post("/farmers", payload);
        }
        farmerModal.hide();
        loadFarmers();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function deactivateFarmer(farmerId) {
    if (!confirm("Deactivate this farmer? Their records are kept for history.")) return;
    try {
        await api.del(`/farmers/${farmerId}`);
        loadFarmers();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function viewFarmer(farmerId) {
    document.getElementById("detailModalBody").innerHTML = "Loading...";
    farmerDetailModal.show();
    try {
        const res = await api.get(`/farmers/${farmerId}`);
        const f = res.data;
        document.getElementById("detailModalTitle").textContent = `${f.name} (#${f.farmer_id})`;
        document.getElementById("detailModalBody").innerHTML = `
            <p><strong>Phone:</strong> ${f.phone} &nbsp; <strong>Village:</strong> ${f.village} &nbsp; ${badgeHtml(f.status)}</p>

            <h6 class="mt-3">Land Parcels</h6>
            ${renderMiniTable(f.parcels, [
                ["parcel_id", "ID"], ["crop_name", "Crop"], ["area_acres", "Acres"], ["location", "Location"], ["status", "status"],
            ])}

            <h6 class="mt-3">Water Schedules</h6>
            ${renderMiniTable(f.schedules, [
                ["schedule_id", "ID"], ["canal_name", "Canal"], ["start_time", "datetime"], ["end_time", "datetime"], ["requested_water", "litres"], ["status", "status"],
            ])}

            <h6 class="mt-3">Bills</h6>
            ${renderMiniTable(f.bills, [
                ["bill_id", "ID"], ["water_used", "litres"], ["total_amount", "currency"], ["due_date", "date"], ["status", "status"],
            ])}

            <h6 class="mt-3">Complaints</h6>
            ${renderMiniTable(f.complaints, [
                ["complaint_id", "ID"], ["complaint_type", "Type"], ["description", "Description"], ["status", "status"],
            ])}
        `;
    } catch (err) {
        document.getElementById("detailModalBody").innerHTML = `<p class="text-danger">${err.message}</p>`;
    }
}

// Small generic table renderer used by the farmer detail view.
// cols: array of [field, kind] where kind controls formatting.
function renderMiniTable(rows, cols) {
    if (!rows || !rows.length) return `<p class="text-muted small">None recorded.</p>`;
    const head = cols.map(([, label]) => `<th>${label.charAt(0).toUpperCase() + label.slice(1)}</th>`).join("");
    const body = rows.map((r) => {
        const cells = cols.map(([field, kind]) => {
            const v = r[field];
            let out = v;
            if (kind === "status") out = badgeHtml(v);
            else if (kind === "litres") out = formatLitres(v);
            else if (kind === "currency") out = formatCurrency(v);
            else if (kind === "date") out = formatDate(v);
            else if (kind === "datetime") out = formatDateTime(v);
            return `<td>${out === null || out === undefined ? "-" : out}</td>`;
        }).join("");
        return `<tr>${cells}</tr>`;
    }).join("");
    return `<div class="table-responsive-wrap"><table class="data-table"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}
