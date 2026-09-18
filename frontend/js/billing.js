// billing.js
let billModal;

document.addEventListener("DOMContentLoaded", () => {
    billModal = new bootstrap.Modal(document.getElementById("billModal"));
    loadBills();
});

async function loadBills() {
    const status = document.getElementById("filter-bill-status").value;
    const tbody = document.getElementById("bills-tbody");
    tbody.innerHTML = `<tr><td colspan="9">Loading...</td></tr>`;
    try {
        const path = status ? `/bills?status=${encodeURIComponent(status)}` : "/bills";
        const res = await api.get(path);
        renderBillsTable(res.data);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderBillsTable(rows) {
    const tbody = document.getElementById("bills-tbody");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="9">No bills found.</td></tr>`;
        return;
    }
    tbody.innerHTML = rows.map((b) => `
        <tr>
            <td>${b.bill_id}</td>
            <td>${b.farmer_name}</td>
            <td>${formatLitres(b.water_used)}</td>
            <td>Rs. ${b.rate_per_1000_litres} / 1000L</td>
            <td>${formatCurrency(b.total_amount)}</td>
            <td>${formatCurrency(b.amount_paid)}</td>
            <td>${formatDate(b.due_date)}</td>
            <td>${badgeHtml(b.bill_status)}</td>
            <td class="actions-cell no-print">
                <button class="btn btn-sm btn-outline-secondary" onclick="viewBill(${b.bill_id})"><i class="bi bi-eye"></i></button>
                <button class="btn btn-sm btn-outline-primary" onclick="regenerateBill(${b.schedule_id})"><i class="bi bi-arrow-clockwise"></i></button>
            </td>
        </tr>
    `).join("");
}

async function viewBill(billId) {
    document.getElementById("billModalBody").innerHTML = "Loading...";
    billModal.show();
    try {
        const res = await api.get(`/bills/${billId}`);
        const b = res.data;
        document.getElementById("billModalBody").innerHTML = `
            <h4>Mettur Dam Irrigation -- Water Bill</h4>
            <p class="text-muted small">Demo data. Not an official invoice.</p>
            <table class="table table-sm">
                <tr><th>Bill ID</th><td>#${b.bill_id}</td></tr>
                <tr><th>Farmer</th><td>${b.farmer_name}</td></tr>
                <tr><th>Schedule</th><td>#${b.schedule_id}</td></tr>
                <tr><th>Water Used</th><td>${formatLitres(b.water_used)}</td></tr>
                <tr><th>Rate</th><td>Rs. ${b.rate_per_1000_litres} per 1000 litres</td></tr>
                <tr><th>Total Amount</th><td><strong>${formatCurrency(b.total_amount)}</strong></td></tr>
                <tr><th>Amount Paid</th><td>${formatCurrency(b.amount_paid)}</td></tr>
                <tr><th>Bill Date</th><td>${formatDate(b.bill_date)}</td></tr>
                <tr><th>Due Date</th><td>${formatDate(b.due_date)}</td></tr>
                <tr><th>Status</th><td>${badgeHtml(b.bill_status)}</td></tr>
            </table>
        `;
    } catch (err) {
        document.getElementById("billModalBody").innerHTML = `<p class="text-danger">${err.message}</p>`;
    }
}

async function regenerateBill(scheduleId) {
    try {
        const res = await api.post(`/bills/generate/${scheduleId}`);
        showAlert("alert-box", res.message, "success");
        loadBills();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}
