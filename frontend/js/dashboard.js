// dashboard.js
async function loadDashboard() {
    try {
        const [damRes, damHistRes, canalsRes, schedulesRes, billsRes, complaintsRes, cropWaterRes, usageCanalRes, usageVsSchedRes] =
            await Promise.all([
                api.get("/dam/status"),
                api.get("/dam/history?limit=15"),
                api.get("/canals"),
                api.get("/schedules"),
                api.get("/bills"),
                api.get("/complaints?status=OPEN"),
                api.get("/reports/top-crops"),
                api.get("/reports/water-by-canal"),
                api.get("/reports/usage-vs-scheduled"),
            ]);

        const dam = damRes.data;
        document.getElementById("stat-dam-level").textContent = dam.water_level + " m";
        document.getElementById("stat-available-water").textContent = formatLitres(dam.available_water);

        const canals = canalsRes.data;
        document.getElementById("stat-active-canals").textContent =
            canals.filter((c) => c.status === "ACTIVE").length + " / " + canals.length;

        const schedules = schedulesRes.data;
        const today = new Date().toISOString().slice(0, 10);
        const todaySchedules = schedules.filter((s) => String(s.start_time || "").startsWith(today));
        document.getElementById("stat-today-schedules").textContent = todaySchedules.length;
        document.getElementById("stat-pending").textContent = schedules.filter((s) => s.status === "PENDING").length;

        const totalUsed = (usageCanalRes.data || []).reduce((sum, r) => sum + Number(r.total_water_used || 0), 0);
        document.getElementById("stat-total-used").textContent = formatLitres(totalUsed);

        const bills = billsRes.data;
        const outstanding = bills
            .filter((b) => b.bill_status !== "PAID")
            .reduce((sum, b) => sum + (Number(b.total_amount) - Number(b.amount_paid || 0)), 0);
        document.getElementById("stat-outstanding").textContent = formatCurrency(outstanding);

        document.getElementById("stat-open-complaints").textContent = (complaintsRes.data || []).length;

        renderDamChart(damHistRes.data);
        renderCanalUsageChart(usageCanalRes.data);
        renderCropWaterChart(cropWaterRes.data);
        renderScheduledActualChart(usageVsSchedRes.data);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderDamChart(history) {
    new Chart(document.getElementById("chart-dam-level"), {
        type: "line",
        data: {
            labels: history.map((h) => formatDate(h.recorded_at)),
            datasets: [{ label: "Water Level (m)", data: history.map((h) => h.water_level), borderColor: "#1a6fb0", backgroundColor: "rgba(26,111,176,0.15)", tension: 0.3, fill: true }],
        },
        options: { responsive: true, plugins: { legend: { display: false } } },
    });
}

function renderCanalUsageChart(rows) {
    new Chart(document.getElementById("chart-usage-canal"), {
        type: "bar",
        data: {
            labels: rows.map((r) => r.canal_name),
            datasets: [{ label: "Litres Used", data: rows.map((r) => r.total_water_used), backgroundColor: "#2e9cca" }],
        },
        options: { responsive: true, plugins: { legend: { display: false } } },
    });
}

function renderCropWaterChart(rows) {
    new Chart(document.getElementById("chart-crop-water"), {
        type: "doughnut",
        data: {
            labels: rows.map((r) => r.crop_name),
            datasets: [{ data: rows.map((r) => r.total_water_used), backgroundColor: ["#0b3d5c", "#1a6fb0", "#2e9cca", "#7fc4de", "#b7e4f4"] }],
        },
        options: { responsive: true },
    });
}

function renderScheduledActualChart(rows) {
    const recent = rows.slice(-10);
    new Chart(document.getElementById("chart-scheduled-actual"), {
        type: "bar",
        data: {
            labels: recent.map((r) => "#" + r.schedule_id),
            datasets: [
                { label: "Scheduled", data: recent.map((r) => r.scheduled_water), backgroundColor: "#1a6fb0" },
                { label: "Actual", data: recent.map((r) => r.actual_water), backgroundColor: "#e0a11c" },
            ],
        },
        options: { responsive: true },
    });
}

loadDashboard();
