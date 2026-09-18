// crops.js
let cropModal;

document.addEventListener("DOMContentLoaded", () => {
    cropModal = new bootstrap.Modal(document.getElementById("cropModal"));
    loadCrops();
});

async function loadCrops() {
    const tbody = document.getElementById("crops-tbody");
    tbody.innerHTML = `<tr><td colspan="6">Loading...</td></tr>`;
    try {
        const res = await api.get("/crops");
        renderCropsTable(res.data);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderCropsTable(rows) {
    const tbody = document.getElementById("crops-tbody");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="6">No crops found.</td></tr>`;
        return;
    }
    tbody.innerHTML = rows.map((c) => `
        <tr>
            <td>${c.crop_id}</td>
            <td>${c.crop_name}</td>
            <td>${formatLitres(c.water_requirement_per_acre)}</td>
            <td>${c.crop_duration_days}</td>
            <td>${c.season}</td>
            <td class="actions-cell">
                <button class="btn btn-sm btn-outline-secondary" onclick="openEditCropModal(${c.crop_id})"><i class="bi bi-pencil"></i></button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteCrop(${c.crop_id})"><i class="bi bi-trash"></i></button>
            </td>
        </tr>
    `).join("");
}

function openAddCropModal() {
    document.getElementById("cropModalTitle").textContent = "Add Crop";
    document.getElementById("c-crop-id").value = "";
    document.getElementById("c-name").value = "";
    document.getElementById("c-water").value = "";
    document.getElementById("c-duration").value = "";
    document.getElementById("c-season").value = "KHARIF";
}

async function openEditCropModal(cropId) {
    try {
        const res = await api.get(`/crops/${cropId}`);
        const c = res.data;
        document.getElementById("cropModalTitle").textContent = "Edit Crop";
        document.getElementById("c-crop-id").value = c.crop_id;
        document.getElementById("c-name").value = c.crop_name;
        document.getElementById("c-water").value = c.water_requirement_per_acre;
        document.getElementById("c-duration").value = c.crop_duration_days;
        document.getElementById("c-season").value = c.season;
        cropModal.show();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function saveCrop() {
    const id = document.getElementById("c-crop-id").value;
    const payload = {
        crop_name: document.getElementById("c-name").value.trim(),
        water_requirement_per_acre: document.getElementById("c-water").value,
        crop_duration_days: document.getElementById("c-duration").value,
        season: document.getElementById("c-season").value,
    };
    if (!payload.crop_name || !payload.water_requirement_per_acre || !payload.crop_duration_days) {
        showAlert("alert-box", "Crop name, water requirement and duration are required.");
        return;
    }
    try {
        if (id) {
            await api.put(`/crops/${id}`, payload);
        } else {
            await api.post("/crops", payload);
        }
        cropModal.hide();
        loadCrops();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function deleteCrop(cropId) {
    if (!confirm("Delete this crop? This is only possible if no land parcel uses it.")) return;
    try {
        await api.del(`/crops/${cropId}`);
        loadCrops();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}
