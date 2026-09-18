// api.js -- shared fetch helpers for the Mettur Dam Irrigation frontend.
// Change API_BASE if your Flask backend runs somewhere other than
// localhost:5000 (e.g. after deploying it to a hosting service).
const API_BASE = "https://metturdam-production.up.railway.app/api";

async function apiRequest(path, options = {}) {
    const opts = {
        method: options.method || "GET",
        headers: { "Content-Type": "application/json" },
    };
    if (options.body) opts.body = JSON.stringify(options.body);

    let response;
    try {
        response = await fetch(`${API_BASE}${path}`, opts);
    } catch (err) {
        throw new Error("Could not reach the backend API. Is Flask running on localhost:5000?");
    }

    let payload = null;
    try {
        payload = await response.json();
    } catch (err) {
        // No JSON body (e.g. a raw 500 from the server) -- fall through.
    }

    if (!response.ok) {
        const message = (payload && payload.message) || `Request failed (${response.status})`;
        const error = new Error(message);
        error.status = response.status;
        error.payload = payload;
        throw error;
    }
    return payload;
}

const api = {
    get:  (path) => apiRequest(path, { method: "GET" }),
    post: (path, body) => apiRequest(path, { method: "POST", body }),
    put:  (path, body) => apiRequest(path, { method: "PUT", body }),
    del:  (path) => apiRequest(path, { method: "DELETE" }),
};

function showAlert(containerId, message, type = "danger") {
    const container = document.getElementById(containerId);
    if (!container) return;
    container.innerHTML = `
        <div class="alert alert-${type} alert-dismissible fade show" role="alert">
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
        </div>`;
}

function clearAlert(containerId) {
    const container = document.getElementById(containerId);
    if (container) container.innerHTML = "";
}

function statusBadgeClass(status) {
    const map = {
        ACTIVE: "badge-active", INACTIVE: "badge-inactive", MAINTENANCE: "badge-maintenance", FALLOW: "badge-maintenance",
        PENDING: "badge-pending", APPROVED: "badge-approved", REJECTED: "badge-rejected",
        COMPLETED: "badge-completed", CANCELLED: "badge-cancelled",
        PAID: "badge-approved", UNPAID: "badge-pending", OVERDUE: "badge-rejected",
        OPEN: "badge-pending", IN_PROGRESS: "badge-maintenance", RESOLVED: "badge-approved",
        SUCCESS: "badge-approved", FAILED: "badge-rejected",
    };
    return map[status] || "badge-inactive";
}

function badgeHtml(status) {
    if (!status) return "-";
    return `<span class="status-badge ${statusBadgeClass(status)}">${status}</span>`;
}

function formatDateTime(value) {
    if (!value) return "-";
    const d = new Date(String(value).replace(" ", "T"));
    if (isNaN(d)) return value;
    return d.toLocaleString(undefined, { year: "numeric", month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

function formatDate(value) {
    if (!value) return "-";
    const d = new Date(String(value).replace(" ", "T"));
    if (isNaN(d)) return value;
    return d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

function formatLitres(value) {
    if (value === null || value === undefined) return "-";
    return Number(value).toLocaleString(undefined, { maximumFractionDigits: 2 }) + " L";
}

function formatCurrency(value) {
    if (value === null || value === undefined) return "-";
    return "Rs. " + Number(value).toLocaleString(undefined, { maximumFractionDigits: 2 });
}

function toDatetimeLocalValue(date) {
    const pad = (n) => String(n).padStart(2, "0");
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
