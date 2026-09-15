// Shared, dependency-free UI helpers used across every page.

let toastTimer = null;

export function ensureToastEl() {
  let el = document.getElementById("toast");
  if (!el) {
    el = document.createElement("div");
    el.id = "toast";
    document.body.appendChild(el);
  }
  return el;
}

export function toast(message, type = "default") {
  const el = ensureToastEl();
  el.textContent = message;
  el.className = "";
  if (type === "error") el.classList.add("error");
  if (type === "success") el.classList.add("success");
  // force reflow so repeated toasts re-trigger the transition
  void el.offsetWidth;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), 3200);
}

export function errorMessage(err) {
  if (!err) return "Something went wrong.";
  if (typeof err === "string") return err;
  // Supabase Postgres errors surface the RAISE EXCEPTION text in .message
  return err.message || err.error_description || "Something went wrong.";
}

export function fmtDateTime(iso) {
  if (!iso) return "—";
  const d = new Date(iso);
  return d.toLocaleString(undefined, {
    year: "numeric", month: "short", day: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

export function fmtDate(iso) {
  if (!iso) return "—";
  const d = new Date(iso);
  return d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

export function badge(status, kind = "status") {
  const label = status ? status.charAt(0).toUpperCase() + status.slice(1) : "—";
  const cls = kind === "role" ? `role-${status}` : `status-${status}`;
  return `<span class="badge ${cls}"><span></span>${label}</span>`;
}

export function initials(name) {
  if (!name) return "?";
  const parts = name.trim().split(/\s+/);
  const first = parts[0]?.[0] || "";
  const last = parts.length > 1 ? parts[parts.length - 1][0] : "";
  return (first + last).toUpperCase();
}

/**
 * Simple confirm modal. Returns a Promise<boolean>.
 * options: { title, body, confirmLabel, danger }
 */
export function confirmModal({ title, body, confirmLabel = "Confirm", danger = false }) {
  return new Promise((resolve) => {
    const backdrop = document.createElement("div");
    backdrop.className = "modal-backdrop show";
    backdrop.innerHTML = `
      <div class="modal" role="dialog" aria-modal="true">
        <h2>${title}</h2>
        <p>${body}</p>
        <div class="modal-actions">
          <button class="btn btn-secondary" data-act="cancel">Cancel</button>
          <button class="btn ${danger ? "btn-danger" : ""}" data-act="ok">${confirmLabel}</button>
        </div>
      </div>`;
    document.body.appendChild(backdrop);

    function cleanup(result) {
      backdrop.remove();
      resolve(result);
    }
    backdrop.addEventListener("click", (e) => {
      if (e.target === backdrop) cleanup(false);
    });
    backdrop.querySelector('[data-act="cancel"]').addEventListener("click", () => cleanup(false));
    backdrop.querySelector('[data-act="ok"]').addEventListener("click", () => cleanup(true));
  });
}

/**
 * Prompt modal with a textarea (used for rejection reasons / return notes).
 * Returns Promise<string|null>.
 */
export function promptModal({ title, body, placeholder = "", confirmLabel = "Submit", required = false }) {
  return new Promise((resolve) => {
    const backdrop = document.createElement("div");
    backdrop.className = "modal-backdrop show";
    backdrop.innerHTML = `
      <div class="modal" role="dialog" aria-modal="true">
        <h2>${title}</h2>
        <p>${body}</p>
        <div class="field mt-0">
          <textarea placeholder="${placeholder}"></textarea>
        </div>
        <div class="modal-actions">
          <button class="btn btn-secondary" data-act="cancel">Cancel</button>
          <button class="btn" data-act="ok">${confirmLabel}</button>
        </div>
      </div>`;
    document.body.appendChild(backdrop);
    const textarea = backdrop.querySelector("textarea");
    textarea.focus();

    function cleanup(result) {
      backdrop.remove();
      resolve(result);
    }
    backdrop.addEventListener("click", (e) => {
      if (e.target === backdrop) cleanup(null);
    });
    backdrop.querySelector('[data-act="cancel"]').addEventListener("click", () => cleanup(null));
    backdrop.querySelector('[data-act="ok"]').addEventListener("click", () => {
      const val = textarea.value.trim();
      if (required && !val) {
        textarea.style.borderColor = "var(--rejected)";
        return;
      }
      cleanup(val);
    });
  });
}
