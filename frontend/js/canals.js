// canals.js
let canalModal;

document.addEventListener("DOMContentLoaded", () => {
    canalModal = new bootstrap.Modal(document.getElementById("canalModal"));
    loadCanals();
});

async function loadCanals() {
    const tbody = document.getElementById("canals-tbody");
    tbody.innerHTML = `<tr><td colspan="9">Loading...</td></tr>`;
    try {
        const [canalsRes, utilRes] = await Promise.all([api.get("/canals"), api.get("/canals/utilization")]);
        const utilByCanal = Object.fromEntries(utilRes.data.map((u) => [u.canal_id, u]));
        renderCanalsTable(canalsRes.data, utilByCanal);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderCanalsTable(rows, utilByCanal) {
    const tbody = document.getElementById("canals-tbody");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="9">No canals found.</td></tr>`;
        return;
    }
    tbody.innerHTML = rows.map((c) => {
        const util = utilByCanal[c.canal_id];
        const dailyCapacity = Number(c.capacity_litres_per_hour) * 24;
        const pct = util && dailyCapacity > 0 ? Math.min(100, (Number(util.total_allocated_litres) / dailyCapacity) * 100) : 0;
        return `
        <tr>
            <td>${c.canal_id}</td>
            <td>${c.canal_name}</td>
            <td>${formatLitres(c.capacity_litres_per_hour)}</td>
            <td>${c.source}</td>
            <td>${c.destination}</td>
            <td>${badgeHtml(c.status)}</td>
            <td style="min-width:120px;">
                <div class="utilization-bar"><div class="utilization-bar-fill" style="width:${pct.toFixed(0)}%"></div></div>
                <small class="text-muted">${pct.toFixed(0)}% of daily capacity</small>
            </td>
            <td id="today-${c.canal_id}">...</td>
            <td class="actions-cell">
                <button class="btn btn-sm btn-outline-secondary" onclick="openEditCanalModal(${c.canal_id})"><i class="bi bi-pencil"></i></button>
            </td>
        </tr>`;
    }).join("");

    rows.forEach((c) => {
        api.get(`/canals/${c.canal_id}`).then((res) => {
            const cell = document.getElementById(`today-${c.canal_id}`);
            if (cell) cell.textContent = (res.data.todays_allocations || []).length;
        }).catch(() => {});
    });
}

function openAddCanalModal() {
    document.getElementById("canalModalTitle").textContent = "Add Canal";
    document.getElementById("cn-canal-id").value = "";
    document.getElementById("cn-name").value = "";
    document.getElementById("cn-capacity").value = "";
    document.getElementById("cn-source").value = "";
    document.getElementById("cn-destination").value = "";
    document.getElementById("cn-status").value = "ACTIVE";
}

async function openEditCanalModal(canalId) {
    try {
        const res = await api.get(`/canals/${canalId}`);
        const c = res.data;
        document.getElementById("canalModalTitle").textContent = "Edit Canal";
        document.getElementById("cn-canal-id").value = c.canal_id;
        document.getElementById("cn-name").value = c.canal_name;
        document.getElementById("cn-capacity").value = c.capacity_litres_per_hour;
        document.getElementById("cn-source").value = c.source;
        document.getElementById("cn-destination").value = c.destination;
        document.getElementById("cn-status").value = c.status;
        canalModal.show();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function saveCanal() {
    const id = document.getElementById("cn-canal-id").value;
    const payload = {
        canal_name: document.getElementById("cn-name").value.trim(),
        capacity_litres_per_hour: document.getElementById("cn-capacity").value,
        source: document.getElementById("cn-source").value.trim(),
        destination: document.getElementById("cn-destination").value.trim(),
        status: document.getElementById("cn-status").value,
    };
    if (!payload.canal_name || !payload.capacity_litres_per_hour || !payload.source || !payload.destination) {
        showAlert("alert-box", "All fields are required.");
        return;
    }
    try {
        if (id) {
            await api.put(`/canals/${id}`, payload);
        } else {
            await api.post("/canals", payload);
        }
        canalModal.hide();
        loadCanals();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}
