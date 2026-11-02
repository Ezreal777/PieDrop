/* PieDrop site interactions: hero disc mock + copy buttons */
(function () {
  "use strict";

  /* ---- hero disc mock ---- */
  var disc = document.querySelector(".disc");
  if (disc) {
    var card = document.querySelector(".panel-card");
    var sectors = disc.querySelectorAll(".sector");
    var typedEl = document.querySelector(".typed");
    var emptyEl = document.querySelector(".card-empty");
    var current = null;
    var timer = null;

    function esc(s) {
      return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    var labels = disc.querySelectorAll(".sector-label");

    function dimLabels(key) {
      labels.forEach(function (l) {
        l.classList.toggle("dim", l.getAttribute("data-for") !== key);
      });
    }

    function show(key) {
      var s = disc.getAttribute("data-sessions");
      var sessions;
      try { sessions = JSON.parse(s); } catch (e) { return; }
      var data = sessions[key];
      if (!data || !card) return;
      current = data;
      card.classList.add("has-session");
      emptyEl.style.display = "none";
      card.querySelector(".session-name").textContent = data.name;
      card.querySelector(".session-name").style.background = data.tint;
      card.querySelector(".session-name").style.color = data.ink;
      card.querySelector(".session-title").textContent = data.title;
      card.querySelector(".session-tty").textContent = data.term + " · " + data.tty;
      card.querySelector(".row-terminal .v").textContent = data.term;
      var draftRow = card.querySelector(".row-draft");
      if (data.draft) {
        draftRow.style.display = "";
        draftRow.querySelector(".v").textContent = data.draft;
        card.querySelector(".session-hint").textContent = data.hint;
      } else {
        draftRow.style.display = "none";
        card.querySelector(".session-hint").textContent = data.hintNoDraft || data.hint;
      }
      dimLabels(key);
    }

    function reset() {
      if (!card) return;
      card.classList.remove("has-session");
      if (emptyEl) emptyEl.style.display = "";
      current = null;
      sectors.forEach(function (sec) { sec.classList.remove("dim", "active"); });
      labels.forEach(function (l) { l.classList.remove("dim"); });
    }

    sectors.forEach(function (sec) {
      var key = sec.getAttribute("data-cli");
      sec.addEventListener("mouseenter", function () {
        sectors.forEach(function (o) { if (o !== sec) o.classList.add("dim"); });
        show(key);
      });
      sec.addEventListener("mouseleave", reset);
      sec.addEventListener("focus", function () { show(key); });
      sec.addEventListener("blur", reset);
      sec.addEventListener("click", function () {
        show(key);
        sec.classList.add("active");
        typePath(" " + (current && current.path ? current.path : ""));
      });
    });

    function typePath(path) {
      if (!typedEl) return;
      if (timer) { clearInterval(timer); timer = null; }
      typedEl.textContent = "";
      var i = 0;
      timer = setInterval(function () {
        typedEl.textContent = path.slice(0, i);
        i += 1;
        if (i > path.length) { clearInterval(timer); timer = null; }
      }, 28);
    }
  }

  /* ---- copy buttons ---- */
  document.querySelectorAll("[data-copy]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var pre = btn.closest("pre");
      var code = pre ? pre.querySelector("code") : null;
      var text = code ? code.textContent : "";
      if (!text) return;
      var done = function () {
        btn.classList.add("copied");
        var old = btn.textContent;
        btn.textContent = btn.getAttribute("data-copied-label") || "Copied";
        setTimeout(function () {
          btn.classList.remove("copied");
          btn.textContent = old;
        }, 1400);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, done);
      } else {
        var ta = document.createElement("textarea");
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand("copy"); } catch (e) {}
        document.body.removeChild(ta);
        done();
      }
    });
  });
})();
