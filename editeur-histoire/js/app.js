// Interface de l'éditeur : liste des visites et des personnages, inspecteur, test du dialogue, fichiers.
(function () {
  const GS = window.GS;
  const $ = (s, r = document) => r.querySelector(s);
  const esc = (s) => GS.esc(s);
  const LS_KEY = "gardien-histoire.story";
  const LS_UI = "gardien-histoire.ui";

  const app = {
    story: GS.newStory(),
    tab: "visits",
    itemId: null,
    visitId: null,
    nodeId: null,
    charId: null,
    fileHandle: null,
    dirty: false,
    filter: "",
  };
  window.app = app;

  // ------------------------------------------------------------------ éléments
  const el = {
    title: $("#storyTitle"),
    side: $("#sidePanel"),
    issues: $("#issues"),
    graph: $("#graph"),
    overview: $("#overview"),
    insp: $("#inspector"),
    status: $("#status"),
    toolbar: $("#toolbar"),
    fileInput: $("#fileInput"),
  };

  const graph = new GS.Graph(el.graph, {
    story: () => app.story,
    visit: () => currentVisit(),
    selected: () => app.nodeId,
    select: (id) => { app.nodeId = id; renderGraph(); renderInspector(); },
    changed: (structural) => commit(structural ? "all" : "save"),
    linkDropEmpty: (from, key, x, y) => {
      const v = currentVisit();
      const id = GS.nextNodeId(v);
      const src = v.nodes[from];
      // après une réplique du personnage, on propose une réponse ; sinon une réplique
      const type = src.type === "line" && src.speaker !== GS.PLAYER ? "line" : "line";
      v.nodes[id] = GS.newNode(type, v, x, y);
      GS.setOutput(src, key, id);
      app.nodeId = id;
      commit("all");
      focusText();
    },
    createAt: (type, x, y) => addNode(type, x, y),
  });

  function currentVisit() {
    return app.story.visits.find((v) => v.id === app.visitId) || null;
  }

  // ------------------------------------------------------------------ sauvegarde et rendu
  let saveTimer = null;
  function commit(what) {
    app.dirty = true;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      try { localStorage.setItem(LS_KEY, GS.serialize(app.story)); } catch (e) { /* stockage plein ou bloqué */ }
      saveUi();
    }, 300);
    updateStatus();
    if (what === "all") {
      renderSide();
      renderGraph();
      renderInspector();
    } else if (what === "graph") {
      renderGraph();
    } else if (what === "side") {
      renderSide();
      renderGraph();
    }
    renderIssues();
  }

  function saveUi() {
    try { localStorage.setItem(LS_UI, JSON.stringify({ visitId: app.visitId, tab: app.tab })); } catch (e) {}
  }

  function updateStatus() {
    const where = app.fileHandle ? app.fileHandle.name : "ce navigateur";
    el.status.textContent = app.dirty ? `Modifié — brouillon gardé dans le navigateur` : `Enregistré (${where})`;
    el.status.classList.toggle("dirty", app.dirty);
  }

  function renderAll() {
    el.title.value = app.story.title || "";
    renderTabs();
    renderSide();
    renderGraph();
    renderInspector();
    renderIssues();
    updateStatus();
  }

  function renderGraph() {
    const showOverview = app.tab === "overview";
    el.overview.hidden = !showOverview;
    el.graph.hidden = showOverview;
    el.toolbar.classList.toggle("disabled", !currentVisit() || showOverview);
    if (showOverview) return renderOverview();
    graph.render();
    const v = currentVisit();
    if (!v) el.graph.querySelector(".world").insertAdjacentHTML("beforeend", "");
    $("#emptyGraph").hidden = !!v;
  }

  // ------------------------------------------------------------------ onglets
  function renderTabs() {
    for (const b of document.querySelectorAll(".tabs button")) b.classList.toggle("on", b.dataset.tab === app.tab);
  }
  for (const b of document.querySelectorAll(".tabs button")) {
    b.addEventListener("click", () => {
      app.tab = b.dataset.tab;
      if (app.tab !== "characters") app.charId = null;
      saveUi();
      renderTabs();
      renderSide();
      renderGraph();
      renderInspector();
    });
  }

  // ------------------------------------------------------------------ panneau de gauche
  function renderSide() {
    const s = app.story;
    if (app.tab === "visits" || app.tab === "overview") {
      const days = new Map();
      for (const v of s.visits) {
        let k = v.day_min && v.day_max && v.day_min === v.day_max ? "Jour " + v.day_min
          : v.day_min || v.day_max ? `Jours ${v.day_min || "…"} à ${v.day_max || "…"}` : "N'importe quel jour";
        if (v.kind === "night") k = "🌙 Nuits — " + k.toLowerCase();
        if (!days.has(k)) days.set(k, []);
        days.get(k).push(v);
      }
      const keys = [...days.keys()].sort((a, b) => sortKey(a) - sortKey(b));
      const f = app.filter.toLowerCase();
      let html = `<div class="side-head"><input id="filter" placeholder="Chercher une visite, un texte..." value="${esc(app.filter)}">
        <button id="addVisit" class="primary" title="Nouvelle visite">+ Visite</button><button id="addNight" title="Nouvel événement de nuit">+ 🌙</button></div>`;
      if (!s.characters.length) html += `<p class="hint">Commencez par créer un personnage (onglet Personnages), ou ouvrez le fichier <code>data/story/story.json</code> du jeu.</p>`;
      for (const k of keys) {
        const items = days.get(k).filter((v) => !f || JSON.stringify(v).toLowerCase().includes(f));
        if (!items.length) continue;
        html += `<h3>${esc(k)}</h3><ul class="vlist">`;
        for (const v of items.sort((a, b) => b.priority - a.priority)) {
          const c = s.characters.find((c) => c.id === v.character);
          const conds = (v.conditions || []).map((x) => GS.describeCond(x, s));
          const who = v.kind === "night" ? (GS.ACTORS[v.actor || ""] || v.actor) : (c ? c.name : v.character);
          html += `<li data-id="${esc(v.id)}" class="${v.id === app.visitId ? "on" : ""}">
            <span class="dot" style="background:${v.kind === "night" ? "#2e3557" : c ? c.color : "#999"}"></span>
            <div><b>${esc(v.title || v.id)}</b><small>${esc(who)} · priorité ${v.priority}${conds.length ? " · si " + esc(conds.join(", ")) : ""}</small></div></li>`;
        }
        html += `</ul>`;
      }
      el.side.innerHTML = html;
      $("#filter").addEventListener("input", (e) => { app.filter = e.target.value; renderSide(); const i = $("#filter"); i.focus(); i.setSelectionRange(i.value.length, i.value.length); });
      $("#addVisit").addEventListener("click", () => {
        if (!s.characters.length) { alert("Créez d'abord un personnage."); return; }
        const v = GS.newVisit(s);
        s.visits.push(v);
        selectVisit(v.id);
        commit("all");
      });
      $("#addNight").addEventListener("click", () => {
        const v = GS.newVisit(s);
        v.kind = "night";
        v.id = GS.uniqueId("nuit", new Set(s.visits.map((x) => x.id)));
        v.title = "Nouvel événement de nuit";
        v.character = GS.NARRATOR;
        v.actor = "";
        v.nodes.n1.speaker = GS.NARRATOR;
        s.visits.push(v);
        selectVisit(v.id);
        commit("all");
      });
      for (const li of el.side.querySelectorAll(".vlist li")) li.addEventListener("click", () => selectVisit(li.dataset.id));
    } else if (app.tab === "characters") {
      let html = `<div class="side-head"><button id="addChar" class="primary">+ Personnage</button></div><ul class="clist">`;
      for (const c of s.characters) {
        const n = s.visits.filter((v) => v.character === c.id).length;
        html += `<li data-id="${esc(c.id)}" class="${c.id === app.charId ? "on" : ""}"><span class="dot" style="background:${c.color}"></span>
          <div><b>${esc(c.name)}</b><small>${esc(c.id)} · ${n} visite${n > 1 ? "s" : ""} · affection ${c.affection_start} (max ${c.affection_max})</small></div></li>`;
      }
      el.side.innerHTML = html + `</ul>`;
      $("#addChar").addEventListener("click", () => {
        const c = GS.newCharacter(s);
        s.characters.push(c);
        app.charId = c.id;
        commit("all");
      });
      for (const li of el.side.querySelectorAll(".clist li")) li.addEventListener("click", () => { app.charId = li.dataset.id; renderSide(); renderInspector(); });
    } else if (app.tab === "items") {
      let html = `<div class="side-head"><button id="addItem" class="primary">+ Objet</button></div>
        <p class="hint">Objets qu'on ramasse dans la montagne et qu'on peut offrir aux visiteurs. ${s.settings.harvest_per_day || 12} objets apparaissent chaque matin, tirés selon leur fréquence.</p><ul class="clist">`;
      for (const it of s.items) {
        const fans = s.characters.filter((c) => (c.gifts || {})[it.id] === "love").map((c) => c.name);
        html += `<li data-id="${esc(it.id)}" class="${it.id === app.itemId ? "on" : ""}"><span class="dot" style="background:${it.color}"></span>
          <div><b>${esc(it.name)}</b><small>${esc((it.zones || []).map((z) => GS.ZONES[z] || z).join(", "))} · fréquence ${it.weight}${fans.length ? " · adoré par " + esc(fans.join(", ")) : ""}</small></div></li>`;
      }
      el.side.innerHTML = html + `</ul>`;
      $("#addItem").addEventListener("click", () => {
        const it = GS.newItem(s);
        s.items.push(it);
        app.itemId = it.id;
        commit("all");
      });
      for (const li of el.side.querySelectorAll(".clist li")) li.addEventListener("click", () => { app.itemId = li.dataset.id; renderSide(); renderInspector(); });
    } else if (app.tab === "settings") {
      const st = s.settings;
      el.side.innerHTML = `<div class="form">
        <h3>Rythme des visites</h3>
        <label>Visites par jour<span class="pair"><input type="number" min="0" max="6" data-k="visits_per_day" data-i="0" value="${st.visits_per_day[0]}"> à <input type="number" min="0" max="6" data-k="visits_per_day" data-i="1" value="${st.visits_per_day[1]}"></span></label>
        <label>Premier visiteur après (s)<span class="pair"><input type="number" min="0" data-k="first_visit_delay" data-i="0" value="${st.first_visit_delay[0]}"> à <input type="number" min="0" data-k="first_visit_delay" data-i="1" value="${st.first_visit_delay[1]}"></span></label>
        <label>Patience d'un visiteur ignoré (s)<span class="pair"><input type="number" min="20" data-one="visitor_patience" value="${st.visitor_patience || 150}"></span></label>
        <label>Objets à ramasser chaque matin<span class="pair"><input type="number" min="0" data-one="harvest_per_day" value="${st.harvest_per_day || 12}"></span></label>
        <label>Pièces au début de la partie<span class="pair"><input type="number" min="0" data-one="start_coins" value="${st.start_coins || 0}"></span></label>
        <label>Entre deux visiteurs (s)<span class="pair"><input type="number" min="0" data-k="visit_gap" data-i="0" value="${st.visit_gap[0]}"> à <input type="number" min="0" data-k="visit_gap" data-i="1" value="${st.visit_gap[1]}"></span></label>
        <p class="hint">Chaque jour, le jeu prend les visites possibles (jour, conditions, pas déjà jouées), une par personnage, les trie par priorité et en garde le nombre ci-dessus. Les visiteurs arrivent à des moments aléatoires pendant que le joueur travaille ; le soir tombe quand les tâches sont faites et que tous sont repartis.</p>
        <h3>Lieux d'attente</h3>
        <ul class="plain">${Object.entries(GS.SPOTS).map(([k, t]) => `<li><code>${k}</code> — ${esc(t)}</li>`).join("")}</ul>
        <h3>Drapeaux utilisés</h3>
        <p class="hint">${GS.allFlags(s).map((f) => `<code>${esc(f)}</code>`).join(" ") || "Aucun pour l'instant."}</p>
      </div>`;
      for (const inp of el.side.querySelectorAll("input[data-one]")) {
        inp.addEventListener("input", () => { st[inp.dataset.one] = +inp.value; commit("save"); });
      }
      for (const inp of el.side.querySelectorAll("input[data-k]")) {
        inp.addEventListener("input", () => { st[inp.dataset.k][+inp.dataset.i] = +inp.value; commit("save"); });
      }
    }
  }

  function sortKey(k) {
    const m = k.match(/(\d+)/);
    return (m ? +m[1] : 999) + (k.startsWith("🌙") ? 1000 : 0);
  }

  function selectVisit(id) {
    app.visitId = id;
    app.nodeId = null;
    if (app.tab !== "visits" && app.tab !== "overview") app.tab = "visits";
    saveUi();
    renderTabs();
    renderSide();
    renderGraph();
    renderInspector();
    requestAnimationFrame(() => graph.fit());
  }

  // ------------------------------------------------------------------ problèmes
  function renderIssues() {
    const list = GS.validate(app.story);
    const errs = list.filter((i) => i.level === "err").length;
    const warns = list.length - errs;
    let html = `<details ${list.length && errs ? "open" : ""}><summary>${errs ? `<span class="bad">${errs} erreur${errs > 1 ? "s" : ""}</span>` : "Aucune erreur"}${warns ? ` · ${warns} avertissement${warns > 1 ? "s" : ""}` : ""}</summary><ul>`;
    for (const i of list.slice(0, 80)) {
      html += `<li class="${i.level}" data-visit="${esc(i.visit || "")}" data-node="${esc(i.node || "")}">${i.visit ? `<code>${esc(i.visit)}${i.node ? " › " + esc(i.node) : ""}</code> ` : ""}${esc(i.msg)}</li>`;
    }
    el.issues.innerHTML = html + `</ul></details>`;
    for (const li of el.issues.querySelectorAll("li[data-visit]")) {
      li.addEventListener("click", () => {
        if (!li.dataset.visit) return;
        selectVisit(li.dataset.visit);
        if (li.dataset.node) { app.nodeId = li.dataset.node; renderGraph(); renderInspector(); }
      });
    }
  }

  // ------------------------------------------------------------------ inspecteur
  function renderInspector() {
    const s = app.story;
    el.insp.innerHTML = "";
    if (app.tab === "items") {
      const it = s.items.find((i) => i.id === app.itemId);
      if (!it) { el.insp.innerHTML = `<p class="hint pad">Choisissez un objet à gauche.</p>`; return; }
      return renderItem(it);
    }
    if (app.tab === "characters") {
      const c = s.characters.find((c) => c.id === app.charId);
      if (!c) { el.insp.innerHTML = `<p class="hint pad">Choisissez un personnage à gauche.</p>`; return; }
      return renderCharacter(c);
    }
    const v = currentVisit();
    if (!v) { el.insp.innerHTML = `<p class="hint pad">Choisissez une visite à gauche, ou créez-en une.</p>`; return; }
    const n = app.nodeId && v.nodes[app.nodeId];
    if (n) renderNode(v, app.nodeId, n);
    else renderVisit(v);
  }

  function section(title, extra) {
    const d = document.createElement("div");
    d.className = "form";
    d.innerHTML = `<h2>${title}</h2>${extra || ""}`;
    el.insp.appendChild(d);
    return d;
  }

  function field(parent, label, input, help) {
    const l = document.createElement("label");
    l.innerHTML = `<span>${label}</span>`;
    l.appendChild(input);
    if (help) l.insertAdjacentHTML("beforeend", `<small>${help}</small>`);
    parent.appendChild(l);
    return input;
  }

  function input(obj, key, opts = {}) {
    const i = document.createElement(opts.area ? "textarea" : "input");
    if (!opts.area) i.type = opts.type || "text";
    if (opts.rows) i.rows = opts.rows;
    if (opts.list) i.setAttribute("list", opts.list);
    if (opts.placeholder) i.placeholder = opts.placeholder;
    i.value = obj[key] == null ? "" : obj[key];
    i.addEventListener("input", () => {
      obj[key] = opts.type === "number" ? (i.value === "" ? 0 : +i.value) : i.value;
      commit(opts.after || "graph");
    });
    return i;
  }

  function select(obj, key, options, after) {
    const sel = document.createElement("select");
    for (const [val, lab] of options) {
      const o = document.createElement("option");
      o.value = val;
      o.textContent = lab;
      if (String(obj[key]) === String(val)) o.selected = true;
      sel.appendChild(o);
    }
    sel.addEventListener("change", () => {
      obj[key] = typeof obj[key] === "number" ? +sel.value : sel.value;
      commit(after || "graph");
    });
    return sel;
  }

  function charOptions(withSpecial) {
    const o = app.story.characters.map((c) => [c.id, c.name]);
    if (withSpecial) o.push([GS.PLAYER, "Vous (le gardien)"], [GS.NARRATOR, "Narration"]);
    return o;
  }

  function button(label, cls, fn, title) {
    const b = document.createElement("button");
    b.textContent = label;
    if (cls) b.className = cls;
    if (title) b.title = title;
    b.addEventListener("click", fn);
    return b;
  }

  function flagDatalist() {
    let dl = $("#flagList");
    if (!dl) { dl = document.createElement("datalist"); dl.id = "flagList"; document.body.appendChild(dl); }
    dl.innerHTML = GS.allFlags(app.story).map((f) => `<option value="${esc(f)}">`).join("");
    let vl = $("#visitList");
    if (!vl) { vl = document.createElement("datalist"); vl.id = "visitList"; document.body.appendChild(vl); }
    vl.innerHTML = app.story.visits.map((v) => `<option value="${esc(v.id)}">${esc(v.title)}</option>`).join("");
  }

  // ---- conditions
  function condEditor(parent, conds, title) {
    flagDatalist();
    const box = document.createElement("div");
    box.className = "rows";
    box.innerHTML = `<div class="rows-title">${title}</div>`;
    conds.forEach((c, i) => {
      const row = document.createElement("div");
      row.className = "row";
      const type = select(c, "type", [["affection", "Affection"], ["flag", "Drapeau"], ["day", "Jour"], ["visited", "Visite jouée"], ["item", "Possède l'objet"], ["coins", "Pièces"]], "none");
      type.addEventListener("change", () => {
        const t = c.type;
        for (const k of Object.keys(c)) delete c[k];
        Object.assign(c, t === "affection" ? { type: t, character: app.story.characters[0] ? app.story.characters[0].id : "", op: ">=", value: 3 }
          : t === "flag" ? { type: t, flag: "", is: true } : t === "day" ? { type: t, op: ">=", value: 2 }
          : t === "item" ? { type: t, item: (app.story.items[0] || {}).id || "", op: ">=", value: 1 }
          : t === "coins" ? { type: t, op: ">=", value: 5 } : { type: t, visit: "", is: true });
        commit("all");
      });
      row.appendChild(type);
      if (c.type === "affection") {
        row.appendChild(select(c, "character", charOptions(false)));
        row.appendChild(select(c, "op", GS.OPS.map((o) => [o, o])));
        const n = input(c, "value", { type: "number" }); n.className = "num"; row.appendChild(n);
      } else if (c.type === "flag") {
        row.appendChild(select({ v: c.is === false ? "0" : "1", get is() { return this.v; } }, "v", [["1", "posé"], ["0", "pas posé"]]));
        row.lastChild.addEventListener("change", (e) => { c.is = e.target.value === "1"; commit("graph"); });
        row.appendChild(input(c, "flag", { list: "flagList", placeholder: "nom_du_drapeau" }));
      } else if (c.type === "item") {
        row.appendChild(select(c, "item", app.story.items.map((i) => [i.id, i.name])));
        row.appendChild(select(c, "op", GS.OPS.map((o) => [o, o])));
        const n = input(c, "value", { type: "number" }); n.className = "num"; row.appendChild(n);
      } else if (c.type === "coins") {
        row.appendChild(select(c, "op", GS.OPS.map((o) => [o, o])));
        const n = input(c, "value", { type: "number" }); n.className = "num"; row.appendChild(n);
      } else if (c.type === "day") {
        row.appendChild(select(c, "op", GS.OPS.map((o) => [o, o])));
        const n = input(c, "value", { type: "number" }); n.className = "num"; row.appendChild(n);
      } else if (c.type === "visited") {
        row.appendChild(select({ v: c.is === false ? "0" : "1" }, "v", [["1", "déjà jouée"], ["0", "pas jouée"]]));
        row.lastChild.addEventListener("change", (e) => { c.is = e.target.value === "1"; commit("graph"); });
        row.appendChild(input(c, "visit", { list: "visitList", placeholder: "id de la visite" }));
      }
      row.appendChild(button("×", "x", () => { conds.splice(i, 1); commit("all"); }, "Retirer"));
      box.appendChild(row);
    });
    box.appendChild(button("+ condition", "small", () => {
      conds.push({ type: "affection", character: (app.story.characters[0] || {}).id || "", op: ">=", value: 3 });
      commit("all");
    }));
    parent.appendChild(box);
  }

  // ---- effets
  function effectEditor(parent, effects, title) {
    flagDatalist();
    const box = document.createElement("div");
    box.className = "rows";
    box.innerHTML = `<div class="rows-title">${title}</div>`;
    effects.forEach((e, i) => {
      const row = document.createElement("div");
      row.className = "row";
      const type = select(e, "type", [["affection", "Affection"], ["flag", "Drapeau"], ["coins", "Pièces"], ["item", "Objet"]], "none");
      type.addEventListener("change", () => {
        const t = e.type;
        for (const k of Object.keys(e)) delete e[k];
        Object.assign(e, t === "affection" ? { type: t, character: currentVisit().character, delta: 1 } : t === "coins" ? { type: t, delta: 1 }
          : t === "item" ? { type: t, item: (app.story.items[0] || {}).id || "", delta: 1 } : { type: t, flag: "", value: true });
        commit("all");
      });
      row.appendChild(type);
      if (e.type === "affection") {
        row.appendChild(select(e, "character", charOptions(false)));
        const n = input(e, "delta", { type: "number" }); n.className = "num"; n.title = "+1, +2, -1..."; row.appendChild(n);
      } else if (e.type === "item") {
        row.appendChild(select(e, "item", app.story.items.map((i) => [i.id, i.name])));
        const n = input(e, "delta", { type: "number" }); n.className = "num"; n.title = "+1 : on le reçoit ; -1 : on le donne"; row.appendChild(n);
      } else if (e.type === "coins") {
        const n = input(e, "delta", { type: "number" }); n.className = "num"; n.title = "+3 : on en reçoit ; -2 : on en perd"; row.appendChild(n);
        row.appendChild(document.createTextNode(" pièce(s)"));
      } else {
        row.appendChild(select({ v: e.value === false ? "0" : "1" }, "v", [["1", "poser"], ["0", "retirer"]]));
        row.lastChild.addEventListener("change", (ev) => { e.value = ev.target.value === "1"; commit("graph"); });
        row.appendChild(input(e, "flag", { list: "flagList", placeholder: "nom_du_drapeau" }));
      }
      row.appendChild(button("×", "x", () => { effects.splice(i, 1); commit("all"); }, "Retirer"));
      box.appendChild(row);
    });
    const add = document.createElement("div");
    add.className = "row";
    add.appendChild(button("+ ♥ affection", "small", () => { effects.push({ type: "affection", character: currentVisit().character, delta: 1 }); commit("all"); }));
    add.appendChild(button("+ drapeau", "small", () => { effects.push({ type: "flag", flag: "", value: true }); commit("all"); }));
    add.appendChild(button("+ pièces", "small", () => { effects.push({ type: "coins", delta: 1 }); commit("all"); }));
    add.appendChild(button("+ objet", "small", () => { effects.push({ type: "item", item: (app.story.items[0] || {}).id || "", delta: 1 }); commit("all"); }));
    box.appendChild(add);
    parent.appendChild(box);
  }

  // ---- visite
  function renderVisit(v) {
    const s = app.story;
    const f = section("Visite", `<p class="hint">Cliquez un noeud du graphe pour l'éditer. Double-clic dans le vide : nouvelle réplique. Tirez depuis un rond à droite d'un noeud pour le relier (lâcher dans le vide crée la réplique suivante).</p>`);
    field(f, "Titre", input(v, "title", { after: "side" }));
    const idIn = document.createElement("input");
    idIn.value = v.id;
    idIn.addEventListener("change", () => {
      const nid = GS.slug(idIn.value);
      if (!nid || s.visits.some((x) => x !== v && x.id === nid)) { idIn.value = v.id; return; }
      v.id = nid;
      app.visitId = nid;
      commit("all");
    });
    field(f, "Identifiant", idIn, "Utilisé par les conditions « visite jouée ».");
    const kind = select(v, "kind", [["day", "Visite de jour"], ["night", "Événement de nuit (après la cloche)"]], "all");
    field(f, "Type", kind, v.kind === "night" ? "Un seul par nuit : le plus prioritaire parmi ceux qui sont possibles ce jour-là." : "");
    if (v.kind === "night") {
      field(f, "Apparition", select(v, "actor", Object.entries(GS.ACTORS), "side"), "La créature sort de l'ombre et s'arrête devant le joueur avant le dialogue.");
    } else {
      field(f, "Personnage", select(v, "character", charOptions(false), "side"));
    }
    const pair = document.createElement("span");
    pair.className = "pair";
    const a = input(v, "day_min", { type: "number", after: "side" }); a.min = 0;
    const b = input(v, "day_max", { type: "number", after: "side" }); b.min = 0;
    pair.append(a, document.createTextNode(" à "), b);
    field(f, "Jours possibles", pair, "0 = pas de limite.");
    field(f, "Priorité", input(v, "priority", { type: "number", after: "side" }), "Les plus prioritaires passent quand il y a trop de visites possibles un même jour.");
    const once = document.createElement("input");
    once.type = "checkbox";
    once.checked = v.once !== false;
    once.addEventListener("change", () => { v.once = once.checked; commit("save"); });
    field(f, "Une seule fois dans la partie", once);
    if (v.kind !== "night") {
      field(f, "Attend le joueur", select(v, "spot", Object.entries(GS.SPOTS)));
      field(f, "Vœu sur l'ema", input(v, "wish", { area: true, rows: 2, placeholder: "Vide = pas d'ema accroché" }));
    }
    condEditor(f, v.conditions, "Conditions pour que la visite ait lieu");
    const actions = document.createElement("div");
    actions.className = "actions";
    actions.append(
      button("▶ Tester le dialogue", "primary", () => openPlaytest(v.id, v.start)),
      button("Dupliquer la visite", "", () => {
        const copy = JSON.parse(JSON.stringify(v));
        copy.id = GS.uniqueId(v.id + "_copie", new Set(s.visits.map((x) => x.id)));
        copy.title = (v.title || v.id) + " (copie)";
        s.visits.push(copy);
        selectVisit(copy.id);
        commit("all");
      }),
      button("Supprimer la visite", "danger", () => {
        if (!confirm(`Supprimer la visite « ${v.title || v.id} » et tout son dialogue ?`)) return;
        s.visits.splice(s.visits.indexOf(v), 1);
        app.visitId = null;
        commit("all");
      })
    );
    f.appendChild(actions);
  }

  // ---- noeud
  function renderNode(v, id, n) {
    const s = app.story;
    const f = section(GS.TYPES[n.type] + (id === v.start ? ` <span class="badge">départ</span>` : ""));
    const idIn = document.createElement("input");
    idIn.value = id;
    idIn.addEventListener("change", () => {
      const nid = GS.slug(idIn.value);
      if (nid && GS.renameNode(v, id, nid)) { app.nodeId = nid; commit("all"); } else idIn.value = id;
    });
    field(f, "Identifiant", idIn);

    if (n.type === "line" || n.type === "choice") {
      const sp = select(n, "speaker", charOptions(true), "all");
      field(f, n.type === "choice" ? "Qui parle avant les choix" : "Qui parle", sp);
      const c = s.characters.find((c) => c.id === n.speaker);
      if (c) field(f, "Expression", select(n, "expr", (c.expressions || ["neutre"]).map((e) => [e, e])), `Portrait : <code>assets/portraits/${esc(c.id)}_${esc(n.expr || "neutre")}.png</code>`);
      const t = field(f, n.type === "choice" ? "Réplique au-dessus des choix (facultative)" : "Texte", input(n, "text", { area: true, rows: n.type === "choice" ? 3 : 6 }));
      t.classList.add("bigtext");
    }
    if (n.type === "line" || n.type === "end") effectEditor(f, n.effects, n.type === "end" ? "Effets à la fin" : "Effets quand cette réplique s'affiche");

    if (n.type === "choice") {
      n.choices.forEach((c, i) => {
        const box = document.createElement("div");
        box.className = "card";
        box.innerHTML = `<div class="card-title">Réponse ${i + 1}${c.next ? ` → <code>${esc(c.next)}</code>` : ' <span class="bad">sans suite</span>'}</div>`;
        const t = input(c, "text", { area: true, rows: 2 });
        box.appendChild(t);
        effectEditor(box, c.effects, "Effets si on la choisit");
        condEditor(box, c.conditions, "Proposée seulement si");
        const r = document.createElement("div");
        r.className = "row";
        if (i > 0) r.appendChild(button("↑", "small", () => { [n.choices[i - 1], n.choices[i]] = [n.choices[i], n.choices[i - 1]]; commit("all"); }, "Monter"));
        r.appendChild(button("Retirer la réponse", "small danger", () => { n.choices.splice(i, 1); commit("all"); }));
        box.appendChild(r);
        f.appendChild(box);
      });
      f.appendChild(button("+ réponse", "", () => { n.choices.push({ text: "", next: "", effects: [], conditions: [] }); commit("all"); }));
    }

    if (n.type === "branch") {
      f.insertAdjacentHTML("beforeend", `<p class="hint">Invisible pour le joueur : la première règle vraie choisit la suite, sinon « sinon ».</p>`);
      n.rules.forEach((r, i) => {
        const box = document.createElement("div");
        box.className = "card";
        box.innerHTML = `<div class="card-title">Règle ${i + 1}${r.next ? ` → <code>${esc(r.next)}</code>` : ' <span class="bad">sans suite</span>'}</div>`;
        condEditor(box, r.conditions, "Si");
        box.appendChild(button("Retirer la règle", "small danger", () => { n.rules.splice(i, 1); commit("all"); }));
        f.appendChild(box);
      });
      f.appendChild(button("+ règle", "", () => { n.rules.push({ conditions: [], next: "" }); commit("all"); }));
    }

    const actions = document.createElement("div");
    actions.className = "actions";
    if (id !== v.start) actions.appendChild(button("⚑ Départ du dialogue", "", () => { v.start = id; commit("all"); }));
    actions.append(
      button("▶ Tester depuis ici", "primary", () => openPlaytest(v.id, id)),
      button("Dupliquer", "", () => duplicateNode()),
      button("Supprimer", "danger", () => deleteNode())
    );
    f.appendChild(actions);
  }

  // ---- personnage
  function renderCharacter(c) {
    const s = app.story;
    const f = section("Personnage");
    field(f, "Nom affiché", input(c, "name", { after: "side" }));
    const idIn = document.createElement("input");
    idIn.value = c.id;
    idIn.addEventListener("change", () => {
      const nid = GS.slug(idIn.value);
      if (!nid || s.characters.some((x) => x !== c && x.id === nid)) { idIn.value = c.id; return; }
      renameCharacter(c.id, nid);
      app.charId = nid;
      commit("all");
    });
    field(f, "Identifiant", idIn, "Sert au nom des portraits : <code>assets/portraits/&lt;id&gt;_&lt;expression&gt;.png</code>. Le renommer met à jour toute l'histoire.");
    field(f, "Couleur du placeholder", input(c, "color", { type: "color", after: "side" }));
    const ex = document.createElement("input");
    ex.value = (c.expressions || []).join(", ");
    ex.addEventListener("input", () => { c.expressions = ex.value.split(",").map((x) => GS.slug(x)).filter(Boolean); commit("save"); });
    field(f, "Expressions", ex, "Séparées par des virgules : neutre, sourire, triste...");
    const pair = document.createElement("span");
    pair.className = "pair";
    pair.append(input(c, "affection_start", { type: "number", after: "side" }), document.createTextNode(" max "), input(c, "affection_max", { type: "number", after: "side" }));
    field(f, "Affection de départ", pair, "L'affection va de -max à +max.");
    field(f, "Pièces offertes", input(c, "coins", { type: "number", after: "side" }), "Pièces jetées dans le tronc à chaque visite, plus 1 par tranche de 3 points d'affection.");
    const animal = document.createElement("input");
    animal.type = "checkbox";
    animal.checked = !!c.animal;
    animal.addEventListener("change", () => { c.animal = animal.checked; commit("side"); });
    field(f, "Animal (pas d'ema ni de carte au présentoir)", animal);
    if (!c.animal) {
      c.gifts = c.gifts || {};
      c.gift_lines = c.gift_lines || {};
      const box = document.createElement("div");
      box.className = "rows";
      box.innerHTML = `<div class="rows-title">Cadeaux : ce que ${esc(c.name)} en pense</div>`;
      for (const it of s.items) {
        const row = document.createElement("div");
        row.className = "row";
        row.insertAdjacentHTML("beforeend", `<span class="dot" style="background:${it.color};margin:0"></span><span style="flex:1">${esc(it.name)}</span>`);
        const holder = { v: c.gifts[it.id] || "neutral" };
        const sel = select(holder, "v", Object.entries(GS.TIERS), "none");
        sel.addEventListener("change", () => {
          if (sel.value === "neutral") delete c.gifts[it.id]; else c.gifts[it.id] = sel.value;
          commit("save");
        });
        row.appendChild(sel);
        box.appendChild(row);
      }
      f.appendChild(box);
      const lines = document.createElement("div");
      lines.className = "rows";
      lines.innerHTML = `<div class="rows-title">Réactions (vide = phrase par défaut)</div>`;
      for (const [tier, label] of Object.entries(GS.TIERS)) {
        const t = input(c.gift_lines, tier, { area: true, rows: 2, placeholder: label, after: "save" });
        lines.appendChild(t);
      }
      f.appendChild(lines);
    }
    field(f, "Notes d'écriture", input(c, "notes", { area: true, rows: 5 }));
    const uses = s.visits.filter((v) => v.character === c.id);
    f.insertAdjacentHTML("beforeend", `<h3>Visites (${uses.length})</h3><ul class="plain">${uses.map((v) => `<li><a href="#" data-v="${esc(v.id)}">${esc(v.title || v.id)}</a> <small>jour ${v.day_min || "…"}–${v.day_max || "…"}</small></li>`).join("")}</ul>`);
    for (const a of f.querySelectorAll("a[data-v]")) a.addEventListener("click", (e) => { e.preventDefault(); app.tab = "visits"; selectVisit(a.dataset.v); });
    const actions = document.createElement("div");
    actions.className = "actions";
    actions.append(
      button("+ Visite pour ce personnage", "primary", () => {
        const v = GS.newVisit(s, c.id);
        s.visits.push(v);
        app.tab = "visits";
        selectVisit(v.id);
        commit("all");
      }),
      button("Supprimer le personnage", "danger", () => {
        if (uses.length && !confirm(`${c.name} a ${uses.length} visite(s). Supprimer quand même le personnage ? (les visites restent, à réattribuer)`)) return;
        if (!uses.length && !confirm(`Supprimer ${c.name} ?`)) return;
        s.characters.splice(s.characters.indexOf(c), 1);
        app.charId = null;
        commit("all");
      })
    );
    f.appendChild(actions);
  }

  // ---- objet
  function renderItem(it) {
    const s = app.story;
    const f = section("Objet");
    field(f, "Nom", input(it, "name", { after: "side" }));
    const idIn = document.createElement("input");
    idIn.value = it.id;
    idIn.addEventListener("change", () => {
      const nid = GS.slug(idIn.value);
      if (!nid || s.items.some((x) => x !== it && x.id === nid)) { idIn.value = it.id; return; }
      for (const c of s.characters) if (c.gifts && c.gifts[it.id] !== undefined) { c.gifts[nid] = c.gifts[it.id]; delete c.gifts[it.id]; }
      it.id = nid;
      app.itemId = nid;
      commit("all");
    });
    field(f, "Identifiant", idIn, "Utilisé par les goûts des personnages et les conditions « possède l'objet ».");
    field(f, "Description", input(it, "description", { area: true, rows: 2 }));
    field(f, "Forme dans le jeu", select(it, "shape", Object.entries(GS.SHAPES)));
    field(f, "Couleur", input(it, "color", { type: "color", after: "side" }));
    field(f, "Fréquence", input(it, "weight", { type: "number", after: "side" }), "Plus elle est haute, plus on en trouve. 1 = rare.");
    const zones = document.createElement("div");
    zones.className = "rows";
    zones.innerHTML = `<div class="rows-title">Où on le trouve</div>`;
    for (const [z, label] of Object.entries(GS.ZONES)) {
      const l = document.createElement("label");
      l.className = "chk";
      const cb = document.createElement("input");
      cb.type = "checkbox";
      cb.checked = (it.zones || []).includes(z);
      cb.addEventListener("change", () => {
        it.zones = Object.keys(GS.ZONES).filter((k) => (k === z ? cb.checked : (it.zones || []).includes(k)));
        commit("side");
      });
      l.append(cb, document.createTextNode(" " + label));
      zones.appendChild(l);
    }
    f.appendChild(zones);
    const rows = s.characters.filter((c) => !c.animal).map((c) => `<li><span class="dot" style="background:${c.color}"></span> ${esc(c.name)} : <b>${esc(GS.TIERS[(c.gifts || {})[it.id] || "neutral"])}</b></li>`);
    f.insertAdjacentHTML("beforeend", `<h3>Goûts des personnages</h3><ul class="plain">${rows.join("")}</ul><p class="hint">Se règle sur la fiche de chaque personnage.</p>`);
    const actions = document.createElement("div");
    actions.className = "actions";
    actions.appendChild(button("Supprimer l'objet", "danger", () => {
      if (!confirm(`Supprimer « ${it.name} » ?`)) return;
      s.items.splice(s.items.indexOf(it), 1);
      for (const c of s.characters) if (c.gifts) delete c.gifts[it.id];
      app.itemId = null;
      commit("all");
    }));
    f.appendChild(actions);
  }

  function renameCharacter(oldId, newId) {
    const s = app.story;
    s.characters.find((c) => c.id === oldId).id = newId;
    const fixC = (conds) => (conds || []).forEach((c) => c.character === oldId && (c.character = newId));
    const fixE = (effs) => (effs || []).forEach((e) => e.character === oldId && (e.character = newId));
    for (const v of s.visits) {
      if (v.character === oldId) v.character = newId;
      fixC(v.conditions);
      for (const n of Object.values(v.nodes)) {
        if (n.speaker === oldId) n.speaker = newId;
        fixE(n.effects);
        (n.choices || []).forEach((c) => { fixE(c.effects); fixC(c.conditions); });
        (n.rules || []).forEach((r) => fixC(r.conditions));
      }
    }
  }

  // ------------------------------------------------------------------ actions sur les noeuds
  function addNode(type, x, y) {
    const v = currentVisit();
    if (!v) return;
    if (x === undefined) {
      const r = el.graph.getBoundingClientRect();
      const p = graph.toWorld(r.left + r.width / 2, r.top + r.height / 3);
      x = p.x - 130; y = p.y;
    }
    const id = GS.nextNodeId(v);
    v.nodes[id] = GS.newNode(type, v, x, y);
    // relie automatiquement depuis le noeud sélectionné s'il n'a pas de suite
    const sel = app.nodeId && v.nodes[app.nodeId];
    if (sel) {
      const free = GS.outputs(sel).find((o) => !o.target);
      if (free) GS.setOutput(sel, free.key, id);
    }
    app.nodeId = id;
    commit("all");
    focusText();
  }

  function focusText() {
    requestAnimationFrame(() => { const t = el.insp.querySelector("textarea.bigtext, .bigtext textarea, textarea"); if (t) t.focus(); });
  }

  function deleteNode() {
    const v = currentVisit();
    if (!v || !app.nodeId) return;
    const n = v.nodes[app.nodeId];
    if (n && ((n.text && n.text.trim()) || (n.choices && n.choices.length > 0)) && !confirm(`Supprimer le noeud « ${app.nodeId} » ?`)) return;
    GS.deleteNode(v, app.nodeId);
    app.nodeId = null;
    commit("all");
  }

  function duplicateNode() {
    const v = currentVisit();
    if (!v || !app.nodeId) return;
    const copy = JSON.parse(JSON.stringify(v.nodes[app.nodeId]));
    copy.x += 40; copy.y += 40;
    const id = GS.nextNodeId(v);
    v.nodes[id] = copy;
    app.nodeId = id;
    commit("all");
  }

  for (const b of el.toolbar.querySelectorAll("[data-add]")) b.addEventListener("click", () => addNode(b.dataset.add));
  $("#btnLayout").addEventListener("click", () => { const v = currentVisit(); if (!v) return; GS.autoLayout(v); commit("graph"); requestAnimationFrame(() => graph.fit()); });
  $("#btnFit").addEventListener("click", () => graph.fit());
  $("#btnTest").addEventListener("click", () => { const v = currentVisit(); if (v) openPlaytest(v.id, v.start); });

  document.addEventListener("keydown", (e) => {
    const typing = /INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName);
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s") { e.preventDefault(); save(); return; }
    if (typing) return;
    if (e.key === "Delete" || e.key === "Backspace") {
      if (graph.deleteSelectedLink()) return;
      if (app.nodeId) deleteNode();
    }
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "d") { e.preventDefault(); duplicateNode(); }
    if (e.key === "Escape") { app.nodeId = null; renderGraph(); renderInspector(); }
  });

  // ------------------------------------------------------------------ vue d'ensemble
  function renderOverview() {
    const s = app.story;
    const maxDay = Math.max(3, ...s.visits.map((v) => v.day_max || v.day_min || 0));
    const st = GS.newState(s);
    let html = `<div class="ov"><h2>Vue d'ensemble</h2>
      <p class="hint">Quelles visites peuvent avoir lieu chaque jour, à quelles conditions. En vert : possibles dès le départ ; en pointillé : dépendent de choix faits plus tôt (affection, drapeaux). Le jeu en garde ${s.settings.visits_per_day[0]} à ${s.settings.visits_per_day[1]} par jour, par ordre de priorité, une par personnage.</p>
      <div class="days">`;
    for (let d = 1; d <= maxDay; d++) {
      const vs = s.visits.filter((v) => (!v.day_min || d >= v.day_min) && (!v.day_max || d <= v.day_max)).sort((a, b) => b.priority - a.priority);
      html += `<div class="day"><h3>Jour ${d}</h3>`;
      for (const v of vs) {
        const c = s.characters.find((c) => c.id === v.character);
        const free = GS.check(v.conditions.filter((x) => x.type === "day"), Object.assign({}, st, { day: d })) && !v.conditions.some((x) => x.type !== "day");
        html += `<div class="ovv ${free ? "free" : "cond"}" data-v="${esc(v.id)}" style="--c:${c ? c.color : "#999"}">
          <b>${esc(v.title || v.id)}</b><small>${esc(c ? c.name : v.character)} · priorité ${v.priority}</small>
          ${v.conditions.length ? `<small class="cond">si ${esc(v.conditions.map((x) => GS.describeCond(x, s)).join(" et "))}</small>` : ""}</div>`;
      }
      html += `</div>`;
    }
    html += `</div><h2>Drapeaux</h2><table class="flags"><tr><th>Drapeau</th><th>Posé par</th><th>Testé par</th></tr>`;
    for (const fl of GS.allFlags(s)) {
      const setBy = [], usedBy = [];
      for (const v of s.visits) {
        if (v.conditions.some((c) => c.type === "flag" && c.flag === fl)) usedBy.push(`${v.id} (visite)`);
        for (const [id, n] of Object.entries(v.nodes)) {
          if ((n.effects || []).some((e) => e.type === "flag" && e.flag === fl)) setBy.push(`${v.id} › ${id}`);
          (n.choices || []).forEach((c, i) => {
            if (c.effects.some((e) => e.type === "flag" && e.flag === fl)) setBy.push(`${v.id} › ${id} (réponse ${i + 1})`);
            if (c.conditions.some((x) => x.type === "flag" && x.flag === fl)) usedBy.push(`${v.id} › ${id}`);
          });
          (n.rules || []).forEach((r) => r.conditions.some((x) => x.type === "flag" && x.flag === fl) && usedBy.push(`${v.id} › ${id}`));
        }
      }
      html += `<tr><td><code>${esc(fl)}</code></td><td>${setBy.map(esc).join("<br>") || '<span class="bad">jamais</span>'}</td><td>${usedBy.map(esc).join("<br>") || '<span class="muted">jamais</span>'}</td></tr>`;
    }
    el.overview.innerHTML = html + `</table></div>`;
    for (const d of el.overview.querySelectorAll(".ovv")) d.addEventListener("click", () => { app.tab = "visits"; selectVisit(d.dataset.v); });
  }

  // ------------------------------------------------------------------ test du dialogue
  const pt = { visitId: null, state: null, node: null, log: [] };
  const modal = $("#playtest");

  function openPlaytest(visitId, from) {
    pt.visitId = visitId;
    pt.state = pt.state || GS.newState(app.story);
    pt.from = from;
    modal.hidden = false;
    renderPtState();
    runFrom(from);
  }
  $("#ptClose").addEventListener("click", () => (modal.hidden = true));
  $("#ptRestart").addEventListener("click", () => runFrom(pt.from));
  $("#ptReset").addEventListener("click", () => { pt.state = GS.newState(app.story); renderPtState(); runFrom(pt.from); });

  function renderPtState() {
    const s = app.story;
    const st = pt.state;
    let html = `<label>Jour <input type="number" min="1" id="ptDay" value="${st.day}"></label><p>Pièces : <b>${st.coins || 0}</b></p>${Object.entries(st.items || {}).filter(([, n]) => n > 0).length ? `<p>Objets : ${Object.entries(st.items).filter(([, n]) => n > 0).map(([i, n]) => esc(GS.itemName(s, i)) + " ×" + n).join(", ")}</p>` : ""}<h4>Affection</h4>`;
    for (const c of s.characters) {
      const m = +c.affection_max || 10;
      html += `<label class="aff"><span class="dot" style="background:${c.color}"></span>${esc(c.name)}
        <input type="range" min="${-m}" max="${m}" value="${st.affection[c.id] || 0}" data-c="${esc(c.id)}"><output>${st.affection[c.id] || 0}</output></label>`;
    }
    html += `<h4>Drapeaux</h4>`;
    for (const f of GS.allFlags(s)) html += `<label class="chk"><input type="checkbox" data-f="${esc(f)}" ${st.flags[f] ? "checked" : ""}> ${esc(f)}</label>`;
    $("#ptState").innerHTML = html;
    $("#ptDay").addEventListener("input", (e) => (st.day = +e.target.value));
    for (const r of $("#ptState").querySelectorAll("input[data-c]")) r.addEventListener("input", () => { st.affection[r.dataset.c] = +r.value; r.nextElementSibling.textContent = r.value; });
    for (const r of $("#ptState").querySelectorAll("input[data-f]")) r.addEventListener("change", () => { if (r.checked) st.flags[r.dataset.f] = true; else delete st.flags[r.dataset.f]; });
  }

  function runFrom(id) {
    pt.log = [];
    $("#ptLog").innerHTML = "";
    step(id);
  }

  function step(id) {
    const s = app.story;
    const v = s.visits.find((x) => x.id === pt.visitId);
    const view = $("#ptView");
    let guard = 0;
    while (guard++ < 200) {
      const n = v && v.nodes[id];
      if (!n) return finish(id ? `Le dialogue mène à « ${id} », qui n'existe pas.` : "Fin (pas de suite).");
      if (n.type === "branch") {
        let next = n.else;
        for (const r of n.rules) if (GS.check(r.conditions, pt.state)) { next = r.next; break; }
        logLine(`<span class="muted">condition ${esc(id)} → ${esc(next || "(rien)")}</span>`);
        id = next;
        continue;
      }
      if (n.type === "end") {
        pop(GS.apply(n.effects, pt.state, s));
        return finish("Fin du dialogue.");
      }
      const speaker = n.speaker || v.character;
      const c = s.characters.find((x) => x.id === speaker);
      const vc = s.characters.find((x) => x.id === v.character);
      const portrait = c || vc;
      view.innerHTML = `<div class="pt-portrait ${c ? "" : "dim"}" style="--c:${portrait ? portrait.color : "#999"}"><span>${esc(portrait ? portrait.name : "")}<br><small>${esc(c ? n.expr || "neutre" : "")}</small></span></div>
        <div class="pt-box"><div class="pt-name">${esc(speaker === GS.NARRATOR ? "" : GS.charName(s, speaker))}</div>
        <div class="pt-text ${speaker === GS.NARRATOR ? "narr" : ""}">${esc(n.text || "")}</div><div class="pt-choices"></div></div>`;
      const box = view.querySelector(".pt-choices");
      if (n.type === "line") {
        pop(GS.apply(n.effects, pt.state, s));
        logLine(`<b>${esc(GS.charName(s, speaker))}</b> ${esc(n.text || "")}`);
        const next = n.next;
        box.appendChild(button("Suite ▸", "primary", () => step(next)));
        return;
      }
      if (n.type === "choice") {
        if (n.text) logLine(`<b>${esc(GS.charName(s, speaker))}</b> ${esc(n.text)}`);
        const opts = n.choices.filter((c) => GS.check(c.conditions, pt.state));
        if (!opts.length) { id = n.next || ""; logLine(`<span class="bad">aucune réponse disponible</span>`); continue; }
        for (const c of opts) {
          box.appendChild(button(c.text || "(vide)", "choice", () => {
            logLine(`<b>Vous</b> ${esc(c.text)}`);
            pop(GS.apply(c.effects, pt.state, s));
            step(c.next);
          }));
        }
        const hidden = n.choices.length - opts.length;
        if (hidden) box.insertAdjacentHTML("beforeend", `<small class="muted">${hidden} réponse(s) masquée(s) par leurs conditions</small>`);
        return;
      }
      id = n.next;
    }
  }

  function pop(changes) {
    for (const e of changes) {
      const now = e.type === "coins" ? pt.state.coins + " pièces" : e.type === "item" ? (pt.state.items[e.item] || 0) + " en poche" : pt.state.affection[e.character];
      logLine(`<span class="${e.delta > 0 ? "love" : "muted"}">${esc(GS.describeEffect(e, app.story))} → ${now}</span>`);
    }
    renderPtState();
  }

  function finish(msg) {
    $("#ptView").innerHTML = `<div class="pt-end"><p>${esc(msg)}</p></div>`;
    $("#ptView .pt-end").appendChild(button("Rejouer", "primary", () => runFrom(pt.from)));
    logLine(`<span class="muted">${esc(msg)}</span>`);
  }

  function logLine(html) {
    const li = document.createElement("li");
    li.innerHTML = html;
    $("#ptLog").appendChild(li);
    li.scrollIntoView({ block: "nearest" });
  }

  // ------------------------------------------------------------------ fichiers
  el.title.addEventListener("input", () => { app.story.title = el.title.value; commit("save"); });

  async function openFile() {
    if (window.showOpenFilePicker) {
      try {
        const [h] = await window.showOpenFilePicker({ types: [{ description: "Histoire JSON", accept: { "application/json": [".json"] } }] });
        const text = await (await h.getFile()).text();
        load(text, h);
      } catch (e) { if (e.name !== "AbortError") alert("Impossible d'ouvrir : " + e.message); }
    } else el.fileInput.click();
  }

  function load(text, handle) {
    let data;
    try { data = JSON.parse(text); } catch (e) { alert("Ce fichier n'est pas un JSON valide : " + e.message); return; }
    if (data.format && data.format !== "gardien-story") { if (!confirm("Ce fichier ne semble pas être une histoire du jeu. L'ouvrir quand même ?")) return; }
    app.story = GS.normalize(data);
    app.fileHandle = handle || null;
    app.visitId = app.story.visits[0] ? app.story.visits[0].id : null;
    app.nodeId = null;
    app.dirty = false;
    pt.state = null;
    try { localStorage.setItem(LS_KEY, GS.serialize(app.story)); } catch (e) {}
    renderAll();
    requestAnimationFrame(() => graph.fit());
  }

  async function save() {
    const text = GS.serialize(app.story);
    const errs = GS.validate(app.story).filter((i) => i.level === "err");
    if (errs.length && !confirm(`L'histoire contient ${errs.length} erreur(s) (voir en bas à gauche). Enregistrer quand même ?`)) return;
    try {
      if (!app.fileHandle && window.showSaveFilePicker) {
        app.fileHandle = await window.showSaveFilePicker({ suggestedName: "story.json", types: [{ description: "Histoire JSON", accept: { "application/json": [".json"] } }] });
      }
      if (app.fileHandle) {
        const w = await app.fileHandle.createWritable();
        await w.write(text);
        await w.close();
        app.dirty = false;
        updateStatus();
        return;
      }
    } catch (e) {
      if (e.name === "AbortError") return;
      alert("Enregistrement impossible : " + e.message + "\nLe fichier va être téléchargé à la place.");
    }
    download(text);
    app.dirty = false;
    updateStatus();
  }

  function download(text) {
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([text], { type: "application/json" }));
    a.download = "story.json";
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  }

  $("#btnOpen").addEventListener("click", openFile);
  $("#btnSave").addEventListener("click", save);
  $("#btnDownload").addEventListener("click", () => download(GS.serialize(app.story)));
  $("#btnNew").addEventListener("click", () => {
    if (!confirm("Commencer une histoire vide ? Le brouillon actuel du navigateur sera remplacé (pensez à enregistrer avant).")) return;
    app.story = GS.newStory();
    app.fileHandle = null;
    app.visitId = null;
    app.nodeId = null;
    commit("all");
    renderAll();
  });
  el.fileInput.addEventListener("change", async () => {
    const f = el.fileInput.files[0];
    if (f) load(await f.text(), null);
    el.fileInput.value = "";
  });
  window.addEventListener("beforeunload", (e) => { if (app.dirty && app.fileHandle) { e.preventDefault(); e.returnValue = ""; } });

  // glisser-déposer un story.json sur la page
  document.addEventListener("dragover", (e) => e.preventDefault());
  document.addEventListener("drop", async (e) => {
    e.preventDefault();
    const f = e.dataTransfer.files[0];
    if (f) load(await f.text(), null);
  });

  // ------------------------------------------------------------------ démarrage
  try {
    const saved = localStorage.getItem(LS_KEY);
    if (saved) app.story = GS.normalize(JSON.parse(saved));
    const ui = JSON.parse(localStorage.getItem(LS_UI) || "{}");
    if (ui.visitId && app.story.visits.some((v) => v.id === ui.visitId)) app.visitId = ui.visitId;
    if (ui.tab) app.tab = ui.tab;
  } catch (e) { /* brouillon illisible : on repart de zéro */ }
  if (!app.visitId && app.story.visits[0]) app.visitId = app.story.visits[0].id;
  app.dirty = false;
  renderAll();
  graph.applyTransform();
  requestAnimationFrame(() => graph.fit());
  window.addEventListener("resize", () => graph.drawLinks());
})();
