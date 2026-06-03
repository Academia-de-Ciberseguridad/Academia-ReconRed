/* =====================================================================
   Operación Red Recon — Scoreboard CTF (JS vanilla, sin dependencias)
   Mejoras progresivas: copiar flag maestro, foco automático y un toque
   de terminal. Funciona aunque JS esté desactivado (todo es opcional).
   ===================================================================== */
(function () {
  "use strict";

  // --- Botón "COPIAR" del flag maestro (M12) -------------------------
  function wireCopyButtons() {
    var buttons = document.querySelectorAll(".copy-btn");
    Array.prototype.forEach.call(buttons, function (btn) {
      btn.addEventListener("click", function () {
        var sel = btn.getAttribute("data-copy");
        var el = sel ? document.querySelector(sel) : null;
        if (!el) return;
        var text = el.textContent.trim();
        var done = function () {
          var prev = btn.textContent;
          btn.textContent = "COPIADO ✔";
          setTimeout(function () { btn.textContent = prev; }, 1400);
        };
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(done, fallbackCopy);
        } else {
          fallbackCopy();
        }
        function fallbackCopy() {
          var ta = document.createElement("textarea");
          ta.value = text;
          ta.setAttribute("readonly", "");
          ta.style.position = "absolute";
          ta.style.left = "-9999px";
          document.body.appendChild(ta);
          ta.select();
          try { document.execCommand("copy"); done(); } catch (e) { /* noop */ }
          document.body.removeChild(ta);
        }
      });
    });
  }

  // --- Foco automático en el primer campo de texto visible -----------
  function autofocusInput() {
    var input = document.querySelector("input[autofocus], input[type=text]");
    if (input && typeof input.focus === "function") {
      try { input.focus(); } catch (e) { /* noop */ }
    }
  }

  // --- Accesibilidad de la barra de progreso -------------------------
  function wireProgress() {
    var bars = document.querySelectorAll(".progress-wrap");
    Array.prototype.forEach.call(bars, function (w) {
      var pct = w.getAttribute("data-progress") || "0";
      w.setAttribute("role", "progressbar");
      w.setAttribute("aria-valuemin", "0");
      w.setAttribute("aria-valuemax", "100");
      w.setAttribute("aria-valuenow", pct);
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    wireCopyButtons();
    autofocusInput();
    wireProgress();
  });
})();
