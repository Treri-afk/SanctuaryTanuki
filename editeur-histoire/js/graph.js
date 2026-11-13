// Éditeur de graphe d'un dialogue : noeuds déplaçables, liens tirés depuis les ports de sortie, déplacement et zoom.
(function () {
  const GS = (window.GS = window.GS || {});

  GS.Graph = function (root, hooks) {
    this.root = root;
    this.hooks = hooks; // { story(), visit(), selected(), select(id), changed(), linkDropEmpty(fromId, key, x, y) }
    this.pan = { x: 0, y: 0 };
    this.zoom = 1;
    this.world = document.createElement("div");
    this.world.className = "world";
    this.svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    this.svg.classList.add("links");
    this.world.appendChild(this.svg);
    root.appendChild(this.world);
    this.selectedLink = null;
    this._bind();
  };

  const P = GS.Graph.prototype;

  P.toWorld = function (clientX, clientY) {
    const r = this.root.getBoundingClientRect();
    return { x: (clientX - r.left - this.pan.x) / this.zoom, y: (clientY - r.top - this.pan.y) / this.zoom };
  };

  P.applyTransform = function () {
    this.world.style.transform = `translate(${this.pan.x}px, ${this.pan.y}px) scale(${this.zoom})`;
    this.root.style.backgroundPosition = `${this.pan.x}px ${this.pan.y}px`;
    this.root.style.backgroundSize = `${24 * this.zoom}px ${24 * this.zoom}px`;
  };

  P.fit = function () {
    const v = this.hooks.visit();
    if (!v) return;
    const ns = Object.values(v.nodes);
    if (!ns.length) return;
    const minX = Math.min(...ns.map((n) => n.x)), minY = Math.min(...ns.map((n) => n.y));
    const maxX = Math.max(...ns.map((n) => n.x + 280)), maxY = Math.max(...ns.map((n) => n.y + 160));
    const r = this.root.getBoundingClientRect();
    // on garde le texte lisible : pas plus petit que 70 %, quitte à ne pas tout voir (on commence par le début)
    this.zoom = Math.max(0.7, Math.min(1.0, Math.min((r.width - 60) / (maxX - minX), (r.height - 60) / (maxY - minY))));
    const start = v.nodes[v.start] || { x: minX, y: minY };
    const fitsW = (maxX - minX) * this.zoom < r.width - 60;
    const fitsH = (maxY - minY) * this.zoom < r.height - 60;
    this.pan.x = 30 - (fitsW ? minX : start.x - 20) * this.zoom;
    this.pan.y = 30 - (fitsH ? minY : Math.max(minY, start.y - 40)) * this.zoom;
    this.applyTransform();
  };

  P.render = function () {
    const story = this.hooks.story();
    const v = this.hooks.visit();
    for (const el of [...this.world.querySelectorAll(".node")]) el.remove();
    this.svg.innerHTML = "";
    if (!v) return;
    const sel = this.hooks.selected();
    for (const [id, n] of Object.entries(v.nodes)) {
      const el = document.createElement("div");
      el.className = "node t-" + n.type + (id === sel ? " sel" : "") + (id === v.start ? " start" : "");
      el.dataset.id = id;
      el.style.left = n.x + "px";
      el.style.top = n.y + "px";
      const head = document.createElement("div");
      head.className = "nhead";
      const who = n.type === "line" || (n.type === "choice" && n.text) ? GS.charName(story, n.speaker) : "";
      const ch = story.characters.find((c) => c.id === n.speaker);
      head.innerHTML = `<span class="in-port" title="Entrée"></span><span class="ntype">${GS.TYPES[n.type]}</span>` +
        (who ? `<span class="nwho" style="--c:${ch ? ch.color : "#7a6f86"}">${esc(who)}${n.type === "line" && n.expr ? " · " + esc(n.expr) : ""}</span>` : "") +
        `<span class="nid">${id === v.start ? "⚑ " : ""}${esc(id)}</span>`;
      el.appendChild(head);
      const body = document.createElement("div");
      body.className = "nbody";
      if (n.type === "line") body.innerHTML = `<p class="ntext">${esc(trim(n.text, 160)) || '<em>réplique vide</em>'}</p>`;
      if (n.type === "choice" && n.text) body.innerHTML = `<p class="ntext">${esc(trim(n.text, 100))}</p>`;
      if (n.type === "end") body.innerHTML = `<p class="ntext muted">Fin du dialogue</p>`;
      const effs = (n.effects || []).map((e) => GS.describeEffect(e, story));
      if (effs.length) body.innerHTML += `<div class="neffects">${effs.map(esc).join("<br>")}</div>`;
      el.appendChild(body);
      // sorties
      const outs = GS.outputs(n);
      if (outs.length) {
        const list = document.createElement("div");
        list.className = "nouts";
        outs.forEach((o, i) => {
          const row = document.createElement("div");
          row.className = "nout";
          let label = "";
          if (n.type === "choice") {
            const c = n.choices[i];
            const extra = [];
            if (c.conditions && c.conditions.length) extra.push("si " + c.conditions.map((x) => GS.describeCond(x, story)).join(", "));
            (c.effects || []).forEach((e) => extra.push(GS.describeEffect(e, story)));
            label = `<span class="olabel">${esc(trim(c.text, 70)) || "<em>réponse vide</em>"}</span>` +
              (extra.length ? `<span class="oextra">${extra.map(esc).join(" · ")}</span>` : "");
          } else if (n.type === "branch") {
            label = o.key === "else" ? `<span class="olabel muted">sinon</span>` :
              `<span class="olabel">si ${esc(n.rules[+o.key.slice(5)].conditions.map((x) => GS.describeCond(x, story)).join(" et ") || "toujours")}</span>`;
          } else {
            label = `<span class="olabel muted">suite</span>`;
          }
          row.innerHTML = label + `<span class="out-port${o.target ? " linked" : ""}" data-key="${o.key}" title="Tirer vers un autre noeud"></span>`;
          list.appendChild(row);
        });
        el.appendChild(list);
      }
      this.world.appendChild(el);
    }
    this.drawLinks();
  };

  P.portPos = function (el) {
    const r = el.getBoundingClientRect();
    return this.toWorld(r.left + r.width / 2, r.top + r.height / 2);
  };

  P.drawLinks = function () {
    const v = this.hooks.visit();
    this.svg.innerHTML = "";
    if (!v) return;
    for (const [id, n] of Object.entries(v.nodes)) {
      const el = this.world.querySelector(`.node[data-id="${cssq(id)}"]`);
      if (!el) continue;
      for (const o of GS.outputs(n)) {
        if (!o.target) continue;
        const tel = this.world.querySelector(`.node[data-id="${cssq(o.target)}"] .in-port`);
        const pel = el.querySelector(`.out-port[data-key="${o.key}"]`);
        if (!tel || !pel) continue;
        const a = this.portPos(pel), b = this.portPos(tel);
        const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
        path.setAttribute("d", curve(a, b));
        const key = id + "|" + o.key;
        path.dataset.key = key;
        path.classList.add("link", "lt-" + n.type);
        if (this.selectedLink === key) path.classList.add("sel");
        this.svg.appendChild(path);
      }
    }
  };

  function curve(a, b) {
    const dx = Math.max(60, Math.abs(b.x - a.x) * 0.5);
    return `M${a.x},${a.y} C${a.x + dx},${a.y} ${b.x - dx},${b.y} ${b.x},${b.y}`;
  }

  P._bind = function () {
    const root = this.root;
    let drag = null;

    root.addEventListener("mousedown", (e) => {
      if (e.button !== 0 && e.button !== 1) return;
      const port = e.target.closest(".out-port");
      const node = e.target.closest(".node");
      const link = e.target.closest("path.link");
      if (port && node) {
        const temp = document.createElementNS("http://www.w3.org/2000/svg", "path");
        temp.classList.add("link", "temp");
        this.svg.appendChild(temp);
        drag = { kind: "link", from: node.dataset.id, key: port.dataset.key, start: this.portPos(port), temp };
        e.preventDefault();
        return;
      }
      if (link) {
        this.selectedLink = link.dataset.key;
        this.hooks.select(null);
        this.drawLinks();
        e.preventDefault();
        return;
      }
      if (node && e.button === 0) {
        const v = this.hooks.visit();
        const n = v.nodes[node.dataset.id];
        this.selectedLink = null;
        if (this.hooks.selected() !== node.dataset.id) this.hooks.select(node.dataset.id);
        const p = this.toWorld(e.clientX, e.clientY);
        drag = { kind: "node", id: node.dataset.id, ox: p.x - n.x, oy: p.y - n.y, moved: false };
        return;
      }
      // fond : déplacer la vue
      this.selectedLink = null;
      drag = { kind: "pan", sx: e.clientX, sy: e.clientY, px: this.pan.x, py: this.pan.y, moved: false };
    });

    window.addEventListener("mousemove", (e) => {
      if (!drag) return;
      if (drag.kind === "pan") {
        this.pan.x = drag.px + e.clientX - drag.sx;
        this.pan.y = drag.py + e.clientY - drag.sy;
        if (Math.abs(e.clientX - drag.sx) + Math.abs(e.clientY - drag.sy) > 3) drag.moved = true;
        this.applyTransform();
      } else if (drag.kind === "node") {
        const v = this.hooks.visit();
        const n = v.nodes[drag.id];
        const p = this.toWorld(e.clientX, e.clientY);
        n.x = Math.round((p.x - drag.ox) / 10) * 10;
        n.y = Math.round((p.y - drag.oy) / 10) * 10;
        const el = this.world.querySelector(`.node[data-id="${cssq(drag.id)}"]`);
        el.style.left = n.x + "px";
        el.style.top = n.y + "px";
        drag.moved = true;
        this.drawLinks();
      } else if (drag.kind === "link") {
        drag.temp.setAttribute("d", curve(drag.start, this.toWorld(e.clientX, e.clientY)));
      }
    });

    window.addEventListener("mouseup", (e) => {
      if (!drag) return;
      const d = drag;
      drag = null;
      if (d.kind === "node" && d.moved) this.hooks.changed(false);
      if (d.kind === "pan" && !d.moved && e.target.closest(".graph") === root && !e.target.closest(".node")) this.hooks.select(null);
      if (d.kind === "link") {
        d.temp.remove();
        const v = this.hooks.visit();
        const target = document.elementFromPoint(e.clientX, e.clientY);
        const tnode = target && target.closest(".node");
        if (tnode && tnode.dataset.id !== d.from) {
          GS.setOutput(v.nodes[d.from], d.key, tnode.dataset.id);
          this.hooks.changed(true);
        } else if (!tnode && target && target.closest(".graph") === root) {
          const p = this.toWorld(e.clientX, e.clientY);
          this.hooks.linkDropEmpty(d.from, d.key, p.x, p.y - 20);
        }
      }
    });

    root.addEventListener("wheel", (e) => {
      e.preventDefault();
      const before = this.toWorld(e.clientX, e.clientY);
      this.zoom = Math.max(0.25, Math.min(1.8, this.zoom * (e.deltaY < 0 ? 1.1 : 1 / 1.1)));
      const r = root.getBoundingClientRect();
      this.pan.x = e.clientX - r.left - before.x * this.zoom;
      this.pan.y = e.clientY - r.top - before.y * this.zoom;
      this.applyTransform();
    }, { passive: false });

    root.addEventListener("dblclick", (e) => {
      if (e.target.closest(".node")) return;
      const p = this.toWorld(e.clientX, e.clientY);
      this.hooks.createAt("line", p.x - 130, p.y - 30);
    });
  };

  P.deleteSelectedLink = function () {
    if (!this.selectedLink) return false;
    const [id, key] = this.selectedLink.split("|");
    const v = this.hooks.visit();
    if (v.nodes[id]) GS.setOutput(v.nodes[id], key, "");
    this.selectedLink = null;
    this.hooks.changed(true);
    return true;
  };

  // Disposition automatique en colonnes, selon la profondeur depuis le départ.
  GS.autoLayout = function (visit) {
    const depth = {};
    const order = [];
    const q = [visit.start];
    if (visit.start) depth[visit.start] = 0;
    while (q.length) {
      const id = q.shift();
      order.push(id);
      for (const o of GS.outputs(visit.nodes[id])) {
        if (o.target && visit.nodes[o.target] && depth[o.target] === undefined) {
          depth[o.target] = depth[id] + 1;
          q.push(o.target);
        }
      }
    }
    let maxd = Math.max(0, ...Object.values(depth));
    for (const id of Object.keys(visit.nodes)) if (depth[id] === undefined) depth[id] = ++maxd;
    const cols = {};
    for (const id of Object.keys(visit.nodes)) (cols[depth[id]] = cols[depth[id]] || []).push(id);
    for (const [d, ids] of Object.entries(cols)) {
      ids.forEach((id, i) => {
        visit.nodes[id].x = 60 + d * 340;
        visit.nodes[id].y = 60 + i * 210;
      });
    }
  };

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  }
  function trim(s, n) {
    s = s || "";
    return s.length > n ? s.slice(0, n - 1) + "…" : s;
  }
  function cssq(s) {
    return String(s).replace(/["\\]/g, "\\$&");
  }
  GS.esc = esc;
})();
