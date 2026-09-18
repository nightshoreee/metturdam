// parcels.js
let parcelModal;
let farmersCache = [];
let cropsCache = [];

document.addEventListener("DOMContentLoaded", async () => {
    parcelModal = new bootstrap.Modal(document.getElementById("parcelModal"));
    await Promise.all([loadFarmersCache(), loadCropsCache()]);
    loadParcels();
});

async function loadFarmersCache() {
    const res = await api.get("/farmers");
    farmersCache = res.data;
    const sel = document.getElementById("p-farmer-id");
    sel.innerHTML = farmersCache.map((f) => `<option value="${f.farmer_id}">${f.name} (#${f.farmer_id})</option>`).join("");
}

async function loadCropsCache() {
    const res = await api.get("/crops");
    cropsCache = res.data;
    const sel = document.getElementById("p-crop-id");
    sel.innerHTML = cropsCache.map((c) => `<option value="${c.crop_id}">${c.crop_name}</option>`).join("");
}

async function loadParcels() {
    const tbody = document.getElementById("parcels-tbody");
    tbody.innerHTML = `<tr><td colspan="9">Loading...</td></tr>`;
    try {
        const res = await api.get("/parcels");
        renderParcelsTable(res.data);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderParcelsTable(rows) {
    const tbody = document.getElementById("parcels-tbody");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="9">No parcels found.</td></tr>`;
        return;
    }
    tbody.innerHTML = rows.map((p) => `
        <tr>
            <td>${p.parcel_id}</td>
            <td>${p.farmer_name}</td>
            <td>${p.crop_name}</td>
            <td>${p.area_acres}</td>
            <td id="req-${p.parcel_id}">...</td>
            <td>${p.location}</td>
            <td>${p.soil_type}</td>
            <td>${badgeHtml(p.status)}</td>
            <td class="actions-cell">
                <button class="btn btn-sm btn-outline-secondary" onclick="openEditParcelModal(${p.parcel_id})"><i class="bi bi-pencil"></i></button>
                <button class="btn btn-sm btn-outline-danger" onclick="deactivateParcel(${p.parcel_id})"><i class="bi bi-slash-circle"></i></button>
            </td>
        </tr>
    `).join("");

    // KILLER FEATURE 2 is computed server-side; fetch it per row (small list, fine for a demo project).
    rows.forEach((p) => {
        api.get(`/parcels/${p.parcel_id}`).then((res) => {
            const cell = document.getElementById(`req-${p.parcel_id}`);
            if (cell) cell.textContent = formatLitres(res.data.required_water_litres);
        }).catch(() => {});
    });
}

function openAddParcelModal() {
    document.getElementById("parcelModalTitle").textContent = "Add Land Parcel";
    document.getElementById("p-parcel-id").value = "";
    document.getElementById("p-area").value = "";
    document.getElementById("p-location").value = "";
    document.getElementById("p-soil").value = "";
    document.getElementById("p-status").value = "ACTIVE";
}

async function openEditParcelModal(parcelId) {
    try {
        const res = await api.get(`/parcels/${parcelId}`);
        const p = res.data;
        document.getElementById("parcelModalTitle").textContent = "Edit Land Parcel";
        document.getElementById("p-parcel-id").value = p.parcel_id;
        document.getElementById("p-farmer-id").value = p.farmer_id;
        document.getElementById("p-crop-id").value = p.crop_id;
        document.getElementById("p-area").value = p.area_acres;
        document.getElementById("p-location").value = p.location;
        document.getElementById("p-soil").value = p.soil_type;
        document.getElementById("p-status").value = p.status;
        parcelModal.show();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function saveParcel() {
    const id = document.getElementById("p-parcel-id").value;
    const payload = {
        farmer_id: document.getElementById("p-farmer-id").value,
        crop_id: document.getElementById("p-crop-id").value,
        area_acres: document.getElementById("p-area").value,
        location: document.getElementById("p-location").value.trim(),
        soil_type: document.getElementById("p-soil").value.trim(),
        status: document.getElementById("p-status").value,
    };
    if (!payload.area_acres || !payload.location || !payload.soil_type) {
        showAlert("alert-box", "Area, location and soil type are required.");
        return;
    }
    try {
        if (id) {
            const { farmer_id, ...updatable } = payload; // farmer cannot be changed on an existing parcel
            await api.put(`/parcels/${id}`, updatable);
        } else {
            await api.post("/parcels", payload);
        }
        parcelModal.hide();
        loadParcels();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function deactivateParcel(parcelId) {
    if (!confirm("Deactivate this land parcel?")) return;
    try {
        await api.del(`/parcels/${parcelId}`);
        loadParcels();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}
