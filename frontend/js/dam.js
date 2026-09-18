// dam.js
document.addEventListener("DOMContentLoaded", loadDamPage);

async function loadDamPage() {
    try {
        const [statusRes, historyRes] = await Promise.all([api.get("/dam/status"), api.get("/dam/history?limit=30")]);
        const dam = statusRes.data;
        document.getElementById("dam-level").textContent = dam.water_level + " m";
        document.getElementById("dam-available").textContent = formatLitres(dam.available_water);
        document.getElementById("dam-release").textContent = formatLitres(dam.release_rate) + "/hr";
        document.getElementById("dam-updated").textContent = formatDateTime(dam.recorded_at);

        renderHistoryChart(historyRes.data);
        renderHistoryTable(historyRes.data);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderHistoryChart(rows) {
    new Chart(document.getElementById("chart-dam-history"), {
        type: "line",
        data: {
            labels: rows.map((r) => formatDate(r.recorded_at)),
            datasets: [
                { label: "Water Level (m)", data: rows.map((r) => r.water_level), borderColor: "#1a6fb0", yAxisID: "y", tension: 0.3 },
                { label: "Available Water (L)", data: rows.map((r) => r.available_water), borderColor: "#e0a11c", yAxisID: "y1", tension: 0.3 },
            ],
        },
        options: {
            responsive: true,
            scales: {
                y:  { type: "linear", position: "left",  title: { display: true, text: "Water Level (m)" } },
                y1: { type: "linear", position: "right", grid: { drawOnChartArea: false }, title: { display: true, text: "Available Water (L)" } },
            },
        },
    });
}

function renderHistoryTable(rows) {
    const tbody = document.getElementById("history-tbody");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="5">No readings yet.</td></tr>`;
        return;
    }
    const reversed = [...rows].reverse();
    tbody.innerHTML = reversed.map((r) => `
        <tr>
            <td>${r.status_id}</td>
            <td>${formatDateTime(r.recorded_at)}</td>
            <td>${r.water_level}</td>
            <td>${formatLitres(r.available_water)}</td>
            <td>${formatLitres(r.release_rate)}</td>
        </tr>
    `).join("");
}

async function recordReading() {
    const payload = {
        water_level: document.getElementById("new-level").value,
        available_water: document.getElementById("new-available").value,
        release_rate: document.getElementById("new-release").value,
    };
    if (!payload.water_level || !payload.available_water || !payload.release_rate) {
        showAlert("alert-box", "All three fields are required to log a reading.");
        return;
    }
    try {
        await api.post("/dam/status", payload);
        document.getElementById("new-level").value = "";
        document.getElementById("new-available").value = "";
        document.getElementById("new-release").value = "";
        loadDamPage();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}
