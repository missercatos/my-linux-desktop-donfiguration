const enabledEl = document.getElementById("enabled");
const alphaEl = document.getElementById("alpha");
const blurEl = document.getElementById("blur");

function save() {
  chrome.storage.sync.set({
    enabled: enabledEl.checked,
    alpha: parseFloat(alphaEl.value),
    blur: parseInt(blurEl.value, 10)
  });
}

chrome.storage.sync.get(["enabled", "alpha", "blur"], (s) => {
  enabledEl.checked = !!s.enabled;
  if (s.alpha !== undefined) alphaEl.value = s.alpha;
  if (s.blur !== undefined) blurEl.value = s.blur;
});

enabledEl.addEventListener("change", save);
alphaEl.addEventListener("input", save);
blurEl.addEventListener("input", save);
