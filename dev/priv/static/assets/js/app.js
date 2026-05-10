// Boots the LiveView client. Depends on phoenix.js + phoenix_live_view.js
// being loaded first (see root layout for the script-tag order).
//
// Vendored mode: no esbuild, no importmaps. Each library exposes a global
// (window.Phoenix.Socket, window.LiveView.LiveSocket) and we wire them
// here.

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

const liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
});

liveSocket.connect();
window.liveSocket = liveSocket;

// Flash dismiss
document.querySelectorAll("[role=alert][data-flash]").forEach((el) => {
  el.addEventListener("click", () => el.setAttribute("hidden", ""));
});
