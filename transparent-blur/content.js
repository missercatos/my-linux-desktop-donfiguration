(() => {
  const overlay = document.createElement("div");
  overlay.id = "tb-overlay";
  (document.head || document.documentElement).appendChild(overlay);

  function apply(settings) {
    if (!settings) return;
    overlay.style.setProperty("--tb-alpha", (settings.alpha ?? 0.5).toFixed(2));
    overlay.style.setProperty("--tb-blur", (settings.blur ?? 0) + "px");
    document.documentElement.classList.toggle("tb-active", !!settings.enabled);
  }

  chrome.storage.sync.get(["enabled", "alpha", "blur"], apply);
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === "sync") {
      chrome.storage.sync.get(["enabled", "alpha", "blur"], apply);
    }
  });
})();
