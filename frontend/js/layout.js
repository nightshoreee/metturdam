// layout.js -- injects the shared sidebar and topbar into every page.
// Edit NAV_LINKS to add/remove pages from the sidebar; every page's
// <div id="sidebar"></div> and <div id="topbar"></div> get filled in
// by renderLayout(activePage), called once near the bottom of each
// HTML file.
const NAV_LINKS = [
    { page: "dashboard",  label: "Dashboard",        href: "dashboard.html",  icon: "bi-speedometer2" },
    { page: "farmers",    label: "Farmers",           href: "farmers.html",    icon: "bi-people" },
    { page: "parcels",    label: "Land Parcels",       href: "parcels.html",    icon: "bi-map" },
    { page: "crops",      label: "Crops",               href: "crops.html",      icon: "bi-flower1" },
    { page: "canals",     label: "Canals",               href: "canals.html",     icon: "bi-signpost-split" },
    { page: "dam",        label: "Dam Status",             href: "dam.html",        icon: "bi-water" },
    { page: "schedules",  label: "Water Scheduling",         href: "schedules.html", icon: "bi-calendar-check" },
    { page: "usage",      label: "Water Usage",                href: "usage.html",     icon: "bi-droplet-half" },
    { page: "billing",    label: "Billing",                      href: "billing.html",   icon: "bi-receipt" },
    { page: "payments",   label: "Payments",                       href: "payments.html",  icon: "bi-cash-coin" },
    { page: "complaints", label: "Complaints",                       href: "complaints.html",icon: "bi-exclamation-triangle" },
    { page: "reports",    label: "Reports",                            href: "reports.html",   icon: "bi-bar-chart" },
];

const PAGE_TITLES = Object.fromEntries(NAV_LINKS.map((l) => [l.page, l.label]));

function renderLayout(activePage) {
    const sidebar = document.getElementById("sidebar");
    const topbar = document.getElementById("topbar");

    if (sidebar) {
        sidebar.innerHTML = `
            <div class="sidebar-brand">
                <i class="bi bi-droplet-fill"></i>
                <span>Mettur Dam<br><small>Irrigation Management</small></span>
            </div>
            <nav class="sidebar-nav">
                ${NAV_LINKS.map(
                    (l) => `<a href="${l.href}" class="nav-link ${l.page === activePage ? "active" : ""}">
                                <i class="bi ${l.icon}"></i> ${l.label}
                            </a>`
                ).join("")}
            </nav>
            <div class="sidebar-footer">Demo Data &middot; Academic DBMS Project</div>
        `;
    }

    if (topbar) {
        topbar.innerHTML = `
            <h1 class="page-title">${PAGE_TITLES[activePage] || ""}</h1>
            <div class="topbar-actions">
                <span class="text-muted small d-none d-md-inline">Mettur Dam Smart Water &amp; Irrigation Management System</span>
            </div>
        `;
    }
}
