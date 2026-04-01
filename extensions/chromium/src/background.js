const BRIDGE_BASE_URL = "http://127.0.0.1:17832";
const STORAGE_KEY = "cosmogony_bridge_token";
const VERSION = "0.1.0";

chrome.action.onClicked.addListener(async (tab) => {
  if (tab.id) {
    await captureCurrentTab(tab.id);
  }
});

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "capture-page",
    title: "Send page to Cosmogony",
    contexts: ["page", "action"]
  });
  chrome.contextMenus.create({
    id: "capture-selection",
    title: "Send selection to Cosmogony",
    contexts: ["selection"]
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === "capture-selection" && info.selectionText) {
    await forwardSelection(info.selectionText, tab);
    return;
  }

  if (info.menuItemId === "capture-page" && tab?.id) {
    await captureCurrentTab(tab.id);
  }
});

chrome.commands.onCommand.addListener(async (command) => {
  if (command !== "capture-current-page") {
    return;
  }

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tab?.id) {
    await captureCurrentTab(tab.id);
  }
});

async function captureCurrentTab(tabId) {
  const token = await ensureHandshake();
  if (!token) {
    return;
  }

  const [result] = await chrome.scripting.executeScript({
    target: { tabId },
    func: extractPagePayload
  });

  if (!result?.result) {
    return;
  }

  const response = await fetch(`${BRIDGE_BASE_URL}/v1/captures/page`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Cosmogony-Token": token
    },
    body: JSON.stringify({
      ...result.result,
      browserName: detectBrowserName()
    })
  });

  if (response.status === 401) {
    await chrome.storage.local.remove(STORAGE_KEY);
    const refreshed = await ensureHandshake(true);
    if (!refreshed) {
      return;
    }
    await fetch(`${BRIDGE_BASE_URL}/v1/captures/page`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Cosmogony-Token": refreshed
      },
      body: JSON.stringify(result.result)
    });
  }
}

async function forwardSelection(selectionText, tab) {
  const token = await ensureHandshake();
  if (!token) {
    return;
  }

  await fetch(`${BRIDGE_BASE_URL}/v1/captures/clipboard`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Cosmogony-Token": token
    },
    body: JSON.stringify({
      text: selectionText,
      sourceApplication: tab?.title ? `Chromium Selection · ${tab.title}` : "Chromium Selection"
    })
  });
}

async function ensureHandshake(force = false) {
  if (!force) {
    const stored = await chrome.storage.local.get(STORAGE_KEY);
    if (stored[STORAGE_KEY]) {
      return stored[STORAGE_KEY];
    }
  }

  const response = await fetch(`${BRIDGE_BASE_URL}/v1/handshake`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      extensionID: chrome.runtime.id,
      version: VERSION
    })
  });

  if (!response.ok) {
    return "";
  }

  const payload = await response.json();
  const token = payload.token || "";
  if (token) {
    await chrome.storage.local.set({ [STORAGE_KEY]: token });
  }
  return token;
}

function extractPagePayload() {
  const selection = String(window.getSelection?.() || "").trim();
  const text = (document.body?.innerText || "").replace(/\s+/g, " ").trim();
  const excerptSource = selection || text;
  return {
    url: location.href,
    title: document.title || location.href,
    selection,
    content: text.slice(0, 12000),
    excerpt: excerptSource.slice(0, 280),
    browserName: document.location.hostname
  };
}

function detectBrowserName() {
  const ua = navigator.userAgent || "";
  if (ua.includes("Edg/")) return "Microsoft Edge";
  if (ua.includes("Brave/")) return "Brave Browser";
  if (ua.includes("Arc/")) return "Arc";
  if (ua.includes("Chrome/")) return "Google Chrome";
  return "Chromium";
}
