// payments.js
let unpaidBills = [];

document.addEventListener("DOMContentLoaded", async () => {
    await loadUnpaidBillOptions();
    loadPayments();
});

async function loadUnpaidBillOptions() {
    const res = await api.get("/bills");
    unpaidBills = res.data.filter((b) => b.bill_status !== "PAID");
    document.getElementById("pay-bill-id").innerHTML = `<option value="">Select bill...</option>` +
        unpaidBills.map((b) => `<option value="${b.bill_id}" data-farmer="${b.farmer_id}" data-due="${(Number(b.total_amount) - Number(b.amount_paid || 0)).toFixed(2)}">
            #${b.bill_id} - ${b.farmer_name} - due Rs. ${(Number(b.total_amount) - Number(b.amount_paid || 0)).toFixed(2)}
        </option>`).join("");
}

function onBillChange() {
    const sel = document.getElementById("pay-bill-id");
    const opt = sel.options[sel.selectedIndex];
    if (opt && opt.dataset.due) {
        document.getElementById("pay-amount").value = opt.dataset.due;
    }
}

async function recordPayment() {
    const sel = document.getElementById("pay-bill-id");
    const opt = sel.options[sel.selectedIndex];
    const billId = sel.value;
    if (!billId) {
        showAlert("alert-box", "Please select a bill.");
        return;
    }
    const payload = {
        bill_id: billId,
        farmer_id: opt.dataset.farmer,
        amount_paid: document.getElementById("pay-amount").value,
        payment_mode: document.getElementById("pay-mode").value,
    };
    if (!payload.amount_paid) {
        showAlert("alert-box", "Please enter a payment amount.");
        return;
    }
    try {
        const res = await api.post("/payments", payload);
        showAlert("alert-box", res.message, "success");
        await loadUnpaidBillOptions();
        loadPayments();
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

async function loadPayments() {
    const tbody = document.getElementById("payments-tbody");
    tbody.innerHTML = `<tr><td colspan="6">Loading...</td></tr>`;
    try {
        const res = await api.get("/payments");
        renderPaymentsTable(res.data);
    } catch (err) {
        showAlert("alert-box", err.message);
    }
}

function renderPaymentsTable(rows) {
    const tbody = document.getElementById("payments-tbody");
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="6">No payments recorded yet.</td></tr>`;
        return;
    }
    tbody.innerHTML = rows.map((p) => `
        <tr>
            <td>${p.payment_id}</td>
            <td>#${p.bill_id}</td>
            <td>${formatCurrency(p.amount_paid)}</td>
            <td>${formatDate(p.payment_date)}</td>
            <td>${p.payment_mode}</td>
            <td>${badgeHtml(p.status)}</td>
        </tr>
    `).join("");
}
