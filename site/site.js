/* PieDrop site interactions: hero panel mock + copy buttons */
(function () {
  "use strict";

  /* ---- hero panel mock（SVG 复刻 DiskPanel/DialView/PreviewCard）---- */
  var svg = document.querySelector(".panel-svg");
  if (svg) {
    var sessions = null;
    try { sessions = JSON.parse(svg.getAttribute("data-sessions")); } catch (e) { sessions = null; }
    var sectors = svg.querySelectorAll(".pd-sector");
    var titleEl = svg.querySelector("#pd-title");
    var dotEl = svg.querySelector("#pd-dot");
    var divEl = svg.querySelector("#pd-div");
    var rowsEl = svg.querySelector("#pd-rows");
    var taskEl = svg.querySelector("#pd-task");
    var termEl = svg.querySelector("#pd-term");
    var draftEl = svg.querySelector("#pd-draft");
    var typedEl = document.querySelector(".typed");
    var timer = null;
    var NEUTRAL = svg.getAttribute("data-neutral") || "悬停扇区查看会话";
    var CARD_LEAD = 396;   // 卡片内容左缘（14pt × 2）
    var KEY_W = 56;        // 键列宽（28pt × 2）
    var KEY_GAP = 10;      // 键值间距（5pt × 2）
    var DOT_D = 18;        // 色点直径（9pt × 2）
    var DOT_GAP = 14;      // 点与标题间距（7pt × 2）
    // NSStackView 整体垂直居中：无 KV 行时标题/分隔线下移重新居中
    var Y_TITLE_ROW = 92, Y_DIV_ROW = 124;
    var Y_TITLE_NEUTRAL = 152, Y_DIV_NEUTRAL = 182;

    // 分隔线宽度 = NSStackView 宽度（最宽的可见行）
    function stackWidth(withRows) {
      var w = 0;
      try {
        w = titleEl.getComputedTextLength();
        if (withRows) {
          [taskEl, termEl, draftEl].forEach(function (el) {
            w = Math.max(w, KEY_W + KEY_GAP + el.getComputedTextLength());
          });
        }
      } catch (e) {}
      return w;
    }

    function setDivider(withRows) {
      divEl.setAttribute("x2", (CARD_LEAD + stackWidth(withRows)).toFixed(1));
    }

    function show(key) {
      if (!sessions) return;
      var s = sessions[key];
      if (!s) return;
      dotEl.setAttribute("fill", s.fill);
      dotEl.setAttribute("opacity", "1");
      titleEl.textContent = s.title;
      titleEl.setAttribute("x", CARD_LEAD + DOT_D + DOT_GAP);
      titleEl.setAttribute("y", Y_TITLE_ROW);
      divEl.setAttribute("y1", Y_DIV_ROW);
      divEl.setAttribute("y2", Y_DIV_ROW);
      rowsEl.setAttribute("opacity", "1");
      taskEl.textContent = s.task;
      taskEl.setAttribute("fill", s.ink);
      termEl.textContent = s.term;
      if (s.draft) {
        draftEl.textContent = "▏" + s.draft + " ▌";
        draftEl.setAttribute("fill", "#1c1c1f");
      } else {
        draftEl.textContent = "（输入框为空）";
        draftEl.setAttribute("fill", "#adadb3");
      }
      setDivider(true);
    }

    function reset() {
      sectors.forEach(function (sec) { sec.classList.remove("hover"); });
      dotEl.setAttribute("opacity", "0");
      titleEl.textContent = NEUTRAL;
      titleEl.setAttribute("x", CARD_LEAD);
      titleEl.setAttribute("y", Y_TITLE_NEUTRAL);
      divEl.setAttribute("y1", Y_DIV_NEUTRAL);
      divEl.setAttribute("y2", Y_DIV_NEUTRAL);
      rowsEl.setAttribute("opacity", "0");
      setDivider(false);
    }

    sectors.forEach(function (sec) {
      var key = sec.getAttribute("data-cli");
      sec.addEventListener("mouseenter", function () { show(key); });
      sec.addEventListener("mouseleave", reset);
      sec.addEventListener("focus", function () { show(key); });
      sec.addEventListener("blur", reset);
      sec.addEventListener("click", function () {
        show(key);
        var s = sessions && sessions[key];
        typePath(" " + (s && s.path ? s.path : ""));
      });
    });

    reset();

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
