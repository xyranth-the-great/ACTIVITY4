import { logout } from "./auth.js";
import { initials } from "./ui.js";

/**
 * Role -> nav items. This is the *interface-level* authorization: a
 * Requester never even sees a link to the Users or Audit Log pages.
 * The database-level authorization (RLS + RPC role checks) still
 * applies even if someone types the URL directly.
 */
const NAV = {
  admin: [
    { group: "Workflow", items: [
      { href: "dashboard.html", label: "Overview", key: "dashboard" },
      { href: "equipment.html", label: "Equipment", key: "equipment" },
      { href: "requests.html", label: "Borrowing Requests", key: "requests" },
    ]},
    { group: "Administration", items: [
      { href: "users.html", label: "Users", key: "users" },
      { href: "audit.html", label: "Audit Log", key: "audit" },
    ]},
  ],
  staff: [
    { group: "Workflow", items: [
      { href: "dashboard.html", label: "Overview", key: "dashboard" },
      { href: "equipment.html", label: "Equipment", key: "equipment" },
      { href: "requests.html", label: "Borrowing Requests", key: "requests" },
    ]},
  ],
  requester: [
    { group: "Workflow", items: [
      { href: "dashboard.html", label: "Overview", key: "dashboard" },
      { href: "equipment.html", label: "Equipment", key: "equipment" },
      { href: "requests.html", label: "My Requests", key: "requests" },
    ]},
  ],
};

export function renderSidebar(activeKey, profile) {
  const mount = document.getElementById("sidebar");
  if (!mount) return;

  const groups = NAV[profile.role] || NAV.requester;

  const groupsHtml = groups.map((g) => `
    <div class="nav-group">
      <div class="nav-group-label">${g.group}</div>
      ${g.items.map((item) => `
        <a class="nav-link ${item.key === activeKey ? "active" : ""}" href="${item.href}">
          <span class="nav-icon"></span>${item.label}
        </a>
      `).join("")}
    </div>
  `).join("");

  mount.innerHTML = `
    <div class="brand"><span class="dot"></span>LAB-ASSET</div>
    ${groupsHtml}
    <div class="sidebar-foot">
      <div class="user-chip">
        <div class="user-avatar">${initials(profile.full_name)}</div>
        <div class="user-meta">
          <div class="user-name">${profile.full_name}</div>
          <div class="user-role">${profile.role}</div>
        </div>
      </div>
      <a class="logout-link" id="logout-link">Log out</a>
    </div>
  `;

  document.getElementById("logout-link").addEventListener("click", () => logout());
}
