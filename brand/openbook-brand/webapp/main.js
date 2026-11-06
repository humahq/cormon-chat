// The OpenBook look inside Mattermost: "OpenBook" in place of the Mattermost logo and "Team Edition" badge at the
// top left, and OpenBook's icon in the browser tab. Mattermost's free edition has no setting for these, so this
// finds them on the page (by the badge's words, not by Mattermost's generated class names) and redraws them.
(function () {
  const NAME = "OpenBook";
  const ICON = "data:image/svg+xml," + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="#0b192c"/>' +
    '<path d="M14 18c7-3 13-3 18 1v29c-5-4-11-4-18-1zM50 18c-7-3-13-3-18 1v29c5-4 11-4 18-1z" fill="#00c2cb"/></svg>');

  const style = document.createElement("style");
  style.textContent =
    ".openbook-mark{display:inline-flex;align-items:baseline;gap:8px;white-space:nowrap;" +
    "font:700 18px/1 Inter,-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;letter-spacing:-.5px;" +
    "color:rgba(var(--sidebar-header-text-color-rgb,255,255,255),1)}" +
    ".openbook-mark small{font-weight:500;font-size:11px;letter-spacing:0;opacity:.65}" +
    "[data-openbook] > :not(.openbook-mark){display:none!important}";

  function badges() {
    const out = [];
    const walk = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode: (n) => (/^\s*team edition\s*$/i.test(n.nodeValue) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP),
    });
    while (walk.nextNode()) out.push(walk.currentNode);
    return out;
  }

  function rebrand() {
    for (const text of badges()) {
      let box = text.parentElement;
      while (box && box !== document.body && !box.querySelector("svg")) box = box.parentElement;
      if (!box || box === document.body || box.hasAttribute("data-openbook")) continue;
      box.setAttribute("data-openbook", "");
      const mark = document.createElement("span");
      mark.className = "openbook-mark";
      mark.innerHTML = NAME + "<small>study chat</small>";
      box.appendChild(mark);
    }
    for (const link of document.querySelectorAll("link[rel~='icon']")) {
      if (link.href !== ICON) link.href = ICON;
    }
  }

  let queued = false;
  const observer = new MutationObserver(() => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => { queued = false; rebrand(); });
  });

  class Plugin {
    initialize() {
      document.head.appendChild(style);
      rebrand();
      observer.observe(document.body, { childList: true, subtree: true });
    }
    uninitialize() {
      observer.disconnect();
      style.remove();
    }
  }

  window.registerPlugin("openbook-brand", new Plugin());
})();
