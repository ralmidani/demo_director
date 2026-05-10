// demo_director — runtime
//
// Exposes window.DemoDirector, the object the agent's emitted JS
// calls into. Stays self-contained; no framework or build step.
(function () {
  "use strict";

  const SUBTITLE_ID = "demo-director-subtitle";
  const HIGHLIGHT_ID = "demo-director-highlight";

  function el(id) {
    return document.getElementById(id);
  }

  function findByDemoId(demoId) {
    return document.querySelector('[data-demo-id="' + cssEscape(demoId) + '"]');
  }

  function cssEscape(s) {
    if (window.CSS && CSS.escape) return CSS.escape(s);
    return String(s).replace(/[^a-zA-Z0-9_-]/g, "\\$&");
  }

  function dispatchInput(input) {
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.dispatchEvent(new Event("change", { bubbles: true }));
  }

  // --- subtitle ----------------------------------------------------------
  //
  // Words are revealed one at a time so the reader's eye is drawn to the
  // bar even when it's overlaying a busy page. The reveal cancels any
  // in-flight reveal from a previous subtitle() call.

  const SUBTITLE_WORD_MS = 110;
  let subtitleRevealHandle = null;

  function cancelSubtitleReveal() {
    if (subtitleRevealHandle !== null) {
      clearTimeout(subtitleRevealHandle);
      subtitleRevealHandle = null;
    }
  }

  function subtitle(text) {
    const node = el(SUBTITLE_ID);
    if (!node) return;
    cancelSubtitleReveal();

    if (text == null || text === "") {
      node.textContent = "";
      node.replaceChildren();
      node.removeAttribute("data-visible");
      node.hidden = true;
      return;
    }

    // Render every token up front, hidden — so the layout/wrapping is
    // computed once and earlier words don't shift as later ones reveal.
    // Split on whitespace, preserving each separator.
    const tokens = text.match(/\s+|\S+/g) || [];

    node.replaceChildren();
    const spans = tokens.map(function (tok) {
      const span = document.createElement("span");
      span.textContent = tok;
      span.style.opacity = "0";
      span.style.transition = "opacity 80ms ease";
      node.appendChild(span);
      return span;
    });

    node.hidden = false;
    void node.offsetWidth;
    node.setAttribute("data-visible", "true");

    let i = 0;
    function revealNext() {
      if (i >= spans.length) {
        subtitleRevealHandle = null;
        return;
      }
      const tok = tokens[i];
      spans[i].style.opacity = "1";
      i++;
      // Whitespace tokens don't claim a beat — reveal them with the
      // next word so the cadence stays one beat per word.
      if (/^\s+$/.test(tok) && i < spans.length) {
        revealNext();
        return;
      }
      subtitleRevealHandle = setTimeout(revealNext, SUBTITLE_WORD_MS);
    }
    revealNext();
  }

  // --- highlight ---------------------------------------------------------
  //
  // Position-tracking is done via a per-frame rAF loop while a target
  // is active. CSS transitions on top/left/width/height would race with
  // the page's smooth scroll and visibly drift past the target — so the
  // ring jumps instantly each frame and only the opacity transitions.

  let activeHighlightTarget = null;
  let trackingFrame = null;

  function positionHighlight() {
    const ring = el(HIGHLIGHT_ID);
    if (!ring || !activeHighlightTarget) return;
    if (!document.body.contains(activeHighlightTarget)) {
      hideHighlight();
      return;
    }
    const rect = activeHighlightTarget.getBoundingClientRect();
    const pad = 4;
    ring.style.top = rect.top - pad + "px";
    ring.style.left = rect.left - pad + "px";
    ring.style.width = rect.width + pad * 2 + "px";
    ring.style.height = rect.height + pad * 2 + "px";
  }

  function trackTarget() {
    if (!activeHighlightTarget) {
      trackingFrame = null;
      return;
    }
    positionHighlight();
    trackingFrame = requestAnimationFrame(trackTarget);
  }

  function hideHighlight() {
    const ring = el(HIGHLIGHT_ID);
    activeHighlightTarget = null;
    if (trackingFrame !== null) {
      cancelAnimationFrame(trackingFrame);
      trackingFrame = null;
    }
    if (!ring) return;
    ring.removeAttribute("data-visible");
    ring.hidden = true;
  }

  function highlight(demoId) {
    if (demoId == null) {
      hideHighlight();
      return;
    }
    const target = findByDemoId(demoId);
    const ring = el(HIGHLIGHT_ID);
    if (!target || !ring) return;
    activeHighlightTarget = target;

    // Position before showing so the ring never appears in a stale spot.
    positionHighlight();
    ring.hidden = false;
    void ring.offsetWidth;
    ring.setAttribute("data-visible", "true");

    target.scrollIntoView({ behavior: "smooth", block: "center" });

    if (trackingFrame === null) {
      trackingFrame = requestAnimationFrame(trackTarget);
    }
  }

  // --- fill (instant) ----------------------------------------------------

  function fill(demoId, value) {
    const input = findByDemoId(demoId);
    if (!input) return;
    input.focus();
    input.value = value;
    dispatchInput(input);
  }

  // --- fill (typed) ------------------------------------------------------
  //
  // One character at a time, dispatching `input` events so any
  // phx-change / phx-keyup listeners react as if a human typed.
  // Returns a promise that resolves when typing finishes — the agent's
  // emitted JS can `await` it before clicking the next thing.

  function fillTyped(demoId, value, perCharMs) {
    const input = findByDemoId(demoId);
    if (!input) return Promise.resolve();
    input.focus();
    input.value = "";
    return new Promise(function (resolve) {
      // Track our own buffer instead of reading input.value — frameworks
      // like LiveView morph the DOM mid-typing in response to phx-change
      // events, which would drop characters typed during the round-trip.
      let typed = "";
      let i = 0;
      function step() {
        if (i >= value.length) {
          // Last-line defense: if the DOM diverged from our buffer
          // (e.g. a framework re-render clobbered it), self-correct
          // and warn so demo authors catch silent drops.
          if (input.value !== value) {
            console.warn(
              "[DemoDirector] fillTyped corrected DOM mismatch on " +
                JSON.stringify(demoId) +
                " — DOM had " +
                JSON.stringify(input.value.slice(0, 80)) +
                ", expected " +
                JSON.stringify(value.slice(0, 80))
            );
            input.value = value;
          }
          dispatchInput(input);
          resolve();
          return;
        }
        typed += value[i++];
        input.value = typed;
        input.dispatchEvent(new Event("input", { bubbles: true }));
        setTimeout(step, perCharMs);
      }
      step();
    });
  }

  // --- click -------------------------------------------------------------

  function click(demoId) {
    const target = findByDemoId(demoId);
    if (!target) return;
    target.click();
  }

  // --- export ------------------------------------------------------------

  window.DemoDirector = {
    subtitle: subtitle,
    highlight: highlight,
    fill: fill,
    fillTyped: fillTyped,
    click: click,
  };

  // --- playback socket --------------------------------------------------
  //
  // Connects to the host app's Phoenix endpoint at the socket path
  // rendered into the subtitle div's `data-dd-socket` attribute, joins
  // the playback channel, and evals incoming JS payloads. The Mix task
  // `demo_director.play` broadcasts to that channel.
  //
  // Re-evaluating an already-running playback is a no-op concern of the
  // server; the client unconditionally evals what it receives.

  function evalAsync(js) {
    try {
      hideEndPanel();
      // Wrap in async IIFE so the saved scripts' top-level `await`
      // statements parse and run.
      const fn = new Function("return (async () => {\n" + js + "\n})();");
      Promise.resolve(fn())
        .then(showEndPanel)
        .catch(function (err) {
          console.error("[DemoDirector] playback error:", err);
          showEndPanel();
        });
    } catch (err) {
      console.error("[DemoDirector] eval failed:", err);
    }
  }

  function hideEndPanel() {
    const panel = document.querySelector(".demo-director__end");
    if (panel) panel.parentNode.removeChild(panel);
  }

  function connectPlayback() {
    const subtitleNode = el(SUBTITLE_ID);
    const socketPath = subtitleNode && subtitleNode.dataset.ddSocket;
    if (!socketPath) return;
    if (!window.Phoenix || !window.Phoenix.Socket) return;

    const socket = new window.Phoenix.Socket(socketPath);
    socket.connect();

    const channel = socket.channel("demo_director:playback", {});
    channel.on("play", function (payload) {
      if (payload && typeof payload.js === "string") {
        markDemoActive();
        evalAsync(payload.js);
      }
    });
    channel
      .join()
      .receive("error", function (resp) {
        console.error("[DemoDirector] join failed:", resp);
      });
  }

  function whenReady(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn, { once: true });
    } else {
      fn();
    }
  }

  // --- pending demo (set by the listing page before navigation) -------

  const PENDING_KEY = "demo_director:pending_demo";

  function markDemoActive() {
    // No-op for now; reserved if future flows need cross-page tracking.
  }

  function consumePendingDemo() {
    const raw = sessionStorage.getItem(PENDING_KEY);
    if (!raw) return;
    sessionStorage.removeItem(PENDING_KEY);
    try {
      const { js } = JSON.parse(raw);
      if (typeof js === "string") {
        markDemoActive();
        evalAsync(js);
      }
    } catch (err) {
      console.error("[DemoDirector] resume failed:", err);
    }
  }

  // --- end-of-demo panel ------------------------------------------------
  //
  // Shown after the playback promise resolves. Hides the subtitle bar
  // (which the demo's final `subtitle(null)` cleared) and offers a
  // single CTA back to the demos index.

  function showEndPanel() {
    const subtitleNode = el(SUBTITLE_ID);
    const mountPath = subtitleNode && subtitleNode.dataset.ddMount;
    if (!mountPath) return;

    // Make sure the subtitle isn't competing with the end panel for
    // the same screen real estate, even if the demo didn't end with
    // `subtitle(null)`.
    subtitle(null);
    hideHighlight();

    let panel = document.querySelector(".demo-director__end");
    if (!panel) {
      panel = document.createElement("div");
      panel.className = "demo-director__end";

      const label = document.createElement("span");
      label.className = "demo-director__end__label";
      label.textContent = "Demo finished";
      panel.appendChild(label);

      const link = document.createElement("a");
      link.className = "demo-director__end__back";
      link.href = mountPath + "/demos";
      link.textContent = "← All demos";
      panel.appendChild(link);

      document.body.appendChild(panel);
    }
    void panel.offsetWidth;
    panel.setAttribute("data-visible", "true");
  }

  whenReady(function () {
    consumePendingDemo();

    // Phoenix loads as a deferred script too; wait one tick for the
    // global to land.
    let tries = 0;
    function attempt() {
      if (window.Phoenix && window.Phoenix.Socket) {
        connectPlayback();
      } else if (tries++ < 50) {
        setTimeout(attempt, 100);
      }
    }
    attempt();
  });
})();
