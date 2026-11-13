// Modèle de l'histoire : format, valeurs par défaut, validation, simulation (mêmes règles que le jeu, scripts/story.gd).
(function () {
  const GS = (window.GS = window.GS || {});

  GS.PLAYER = "gardien";
  GS.NARRATOR = "narrateur";
  GS.TYPES = { line: "Réplique", choice: "Choix", branch: "Condition", end: "Fin" };
  GS.SPOTS = {
    offrandes: "Devant le tronc à offrandes",
    ema: "Près du présentoir à ema",
    etang: "Au bord de l'étang",
    the: "Devant la salle de thé",
    jardin: "Devant le jardin sec",
    arbre: "Sous l'arbre sacré",
    torii: "Près du torii d'entrée",
  };
  GS.OPS = [">=", "<=", ">", "<", "==", "!="];
  GS.SHAPES = { kaki: "Kaki", chataigne: "Châtaigne", champignon: "Champignon", feuille: "Feuille", galet: "Galet",
    plume: "Plume", fleur: "Fleur (lys)", pomme_pin: "Pomme de pin", "": "Petite boule" };
  GS.ZONES = { enceinte: "La cour du sanctuaire", sentier: "Le long des sentiers", foret: "Les sous-bois",
    mare: "La mare et le ruisseau", belvedere: "La prairie du belvédère" };
  GS.TIERS = { love: "Adore (+3)", like: "Aime (+1)", neutral: "Sans plus (0)", dislike: "N'aime pas (−1)" };
  GS.ACTORS = { "": "Aucune (souvenir, narration)", renard: "Le renard", tanuki: "Le tanuki", chat: "Le chat de la mare" };

  GS.newStory = function () {
    return {
      format: "gardien-story",
      version: 1,
      title: "Nouvelle histoire",
      settings: { visits_per_day: [2, 3], first_visit_delay: [25, 50], visit_gap: [50, 100], start_coins: 5, visitor_patience: 150 },
      spots: Object.keys(GS.SPOTS),
      characters: [],
      items: [],
      visits: [],
    };
  };

  GS.newItem = function (story) {
    const taken = new Set((story.items || []).map((i) => i.id));
    return { id: GS.uniqueId("objet", taken), name: "Nouvel objet", description: "", color: "#C8442B", shape: "", zones: ["foret"], weight: 2 };
  };

  GS.itemName = function (story, id) {
    const it = (story.items || []).find((i) => i.id === id);
    return it ? it.name : id || "?";
  };

  GS.slug = function (s) {
    return (s || "")
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "");
  };

  GS.uniqueId = function (base, taken) {
    base = GS.slug(base) || "id";
    let id = base;
    let i = 2;
    while (taken.has(id)) id = base + "_" + i++;
    return id;
  };

  GS.newCharacter = function (story) {
    const taken = new Set(story.characters.map((c) => c.id));
    return {
      id: GS.uniqueId("personnage", taken),
      name: "Nouveau personnage",
      color: "#9A8FB0",
      expressions: ["neutre", "sourire", "triste"],
      affection_start: 0,
      affection_max: 10,
      coins: 2,
      notes: "",
    };
  };

  GS.newVisit = function (story, character) {
    const taken = new Set(story.visits.map((v) => v.id));
    const who = character || (story.characters[0] && story.characters[0].id) || "";
    const v = {
      id: GS.uniqueId((who || "visite") + "_visite", taken),
      character: who,
      title: "Nouvelle visite",
      day_min: 1,
      day_max: 1,
      priority: 5,
      once: true,
      spot: "offrandes",
      wish: "",
      conditions: [],
      start: "n1",
      nodes: {},
    };
    v.nodes.n1 = { type: "line", speaker: who, expr: "neutre", text: "", next: "fin", effects: [], x: 60, y: 80 };
    v.nodes.fin = { type: "end", effects: [], x: 420, y: 80 };
    return v;
  };

  GS.nextNodeId = function (visit) {
    let i = 1;
    while (visit.nodes["n" + i]) i++;
    return "n" + i;
  };

  GS.newNode = function (type, visit, x, y) {
    const base = { x: Math.round(x || 0), y: Math.round(y || 0) };
    switch (type) {
      case "line":
        return Object.assign(base, { type, speaker: visit.character, expr: "neutre", text: "", next: "", effects: [] });
      case "choice":
        return Object.assign(base, {
          type, speaker: GS.PLAYER, text: "",
          choices: [
            { text: "Première réponse", next: "", effects: [], conditions: [] },
            { text: "Deuxième réponse", next: "", effects: [], conditions: [] },
          ],
        });
      case "branch":
        return Object.assign(base, {
          type,
          rules: [{ conditions: [{ type: "affection", character: visit.character, op: ">=", value: 3 }], next: "" }],
          else: "",
        });
      default:
        return Object.assign(base, { type: "end", effects: [] });
    }
  };

  // Sorties d'un noeud : [{key, label, target}]
  GS.outputs = function (node) {
    switch (node.type) {
      case "line":
        return [{ key: "next", label: "", target: node.next || "" }];
      case "choice":
        return node.choices.map((c, i) => ({ key: "choice:" + i, label: c.text || "(choix vide)", target: c.next || "" }));
      case "branch":
        return node.rules
          .map((r, i) => ({ key: "rule:" + i, label: "si " + (r.conditions.length ? "…" : "toujours"), target: r.next || "" }))
          .concat([{ key: "else", label: "sinon", target: node.else || "" }]);
      default:
        return [];
    }
  };

  GS.setOutput = function (node, key, target) {
    if (key === "next") node.next = target;
    else if (key === "else") node.else = target;
    else if (key.startsWith("choice:")) node.choices[+key.slice(7)].next = target;
    else if (key.startsWith("rule:")) node.rules[+key.slice(5)].next = target;
  };

  GS.renameNode = function (visit, oldId, newId) {
    if (oldId === newId || visit.nodes[newId]) return false;
    visit.nodes[newId] = visit.nodes[oldId];
    delete visit.nodes[oldId];
    for (const n of Object.values(visit.nodes)) {
      for (const o of GS.outputs(n)) if (o.target === oldId) GS.setOutput(n, o.key, newId);
    }
    if (visit.start === oldId) visit.start = newId;
    return true;
  };

  GS.deleteNode = function (visit, id) {
    delete visit.nodes[id];
    for (const n of Object.values(visit.nodes)) {
      for (const o of GS.outputs(n)) if (o.target === id) GS.setOutput(n, o.key, "");
    }
    if (visit.start === id) visit.start = Object.keys(visit.nodes)[0] || "";
  };

  // Complète un fichier chargé avec les valeurs par défaut (fichiers écrits à la main ou anciens).
  GS.normalize = function (s) {
    const d = GS.newStory();
    s = Object.assign(d, s || {});
    s.settings = Object.assign(GS.newStory().settings, s.settings || {});
    s.items = (s.items || []).map((i) => Object.assign({ description: "", color: "#C8442B", shape: "", zones: ["foret"], weight: 1 }, i));
    s.characters = (s.characters || []).map((c) =>
      Object.assign({ color: "#9A8FB0", expressions: ["neutre"], affection_start: 0, affection_max: 10, coins: 2, notes: "" }, c)
    );
    s.visits = (s.visits || []).map((v) => {
      v = Object.assign({ kind: "day", title: "", day_min: 0, day_max: 0, priority: 0, once: true, spot: "offrandes", wish: "", conditions: [], nodes: {} }, v);
      let i = 0;
      for (const [id, n] of Object.entries(v.nodes)) {
        if (n.x === undefined) { n.x = 60 + (i % 4) * 330; n.y = 60 + Math.floor(i / 4) * 200; }
        n.effects = n.effects || [];
        if (n.type === "choice") n.choices = (n.choices || []).map((c) => Object.assign({ text: "", next: "", effects: [], conditions: [] }, c));
        if (n.type === "branch") n.rules = (n.rules || []).map((r) => Object.assign({ conditions: [], next: "" }, r));
        i++;
      }
      if (!v.start || !v.nodes[v.start]) v.start = Object.keys(v.nodes)[0] || "";
      return v;
    });
    return s;
  };

  // Export : on garde l'ordre des clés lisible et on retire ce qui est vide.
  GS.serialize = function (story) {
    return JSON.stringify(story, null, 2);
  };

  // ------------------------------------------------------------------ textes lisibles
  GS.charName = function (story, id) {
    if (id === GS.PLAYER) return "Vous";
    if (id === GS.NARRATOR) return "Narration";
    const c = story.characters.find((c) => c.id === id);
    return c ? c.name : id || "?";
  };

  GS.describeCond = function (c, story) {
    switch (c.type) {
      case "affection":
        return "affection de " + GS.charName(story, c.character) + " " + c.op + " " + c.value;
      case "flag":
        return (c.is === false ? "PAS « " : "« ") + c.flag + " »";
      case "day":
        return "jour " + c.op + " " + c.value;
      case "visited":
        return (c.is === false ? "pas encore vu " : "déjà vu ") + c.visit;
      case "item":
        return "possède " + GS.itemName(story, c.item) + " " + c.op + " " + c.value;
      case "coins":
        return "pièces " + c.op + " " + c.value;
    }
    return "?";
  };

  GS.describeEffect = function (e, story) {
    if (e.type === "affection") return (e.delta > 0 ? "♥ +" : "♡ ") + e.delta + " " + GS.charName(story, e.character);
    if (e.type === "flag") return (e.value === false ? "retire « " : "pose « ") + e.flag + " »";
    if (e.type === "item") return (e.delta > 0 ? "reçoit " : "donne ") + Math.abs(e.delta) + " " + GS.itemName(story, e.item);
    if (e.type === "coins") return (e.delta > 0 ? "+" : "") + e.delta + " pièce" + (Math.abs(e.delta) > 1 ? "s" : "");
    return "?";
  };

  // ------------------------------------------------------------------ validation
  GS.validate = function (story) {
    const out = [];
    const chars = new Set(story.characters.map((c) => c.id));
    const visitIds = new Set();
    const flagsSet = new Set();
    const flagsUsed = [];
    const scanEffects = (effs) => (effs || []).forEach((e) => e.type === "flag" && e.value !== false && flagsSet.add(e.flag));
    const scanConds = (conds, where) => (conds || []).forEach((c) => {
      if (c.type === "flag") flagsUsed.push([c.flag, where]);
      if (c.type === "affection" && !chars.has(c.character)) out.push({ level: "err", ...where, msg: "Condition sur un personnage inconnu : " + c.character });
    });
    const items = new Set((story.items || []).map((i) => i.id));
    for (const c of story.characters) {
      if (!c.id) out.push({ level: "err", msg: "Un personnage n'a pas d'identifiant." });
      for (const it of Object.keys(c.gifts || {})) if (!items.has(it)) out.push({ level: "warn", msg: `Goûts de ${c.name} : objet inconnu « ${it} ».` });
    }
    for (const it of story.items || []) if (!(it.zones || []).length) out.push({ level: "warn", msg: `L'objet « ${it.name} » n'a aucun lieu : il n'apparaîtra jamais.` });
    for (const v of story.visits) {
      const where = { visit: v.id };
      if (visitIds.has(v.id)) out.push({ level: "err", ...where, msg: "Identifiant de visite en double : " + v.id });
      visitIds.add(v.id);
      if (v.kind !== "night" && !chars.has(v.character)) out.push({ level: "err", ...where, msg: "Personnage inconnu : « " + v.character + " »" });
      if (!v.nodes[v.start]) out.push({ level: "err", ...where, msg: "Pas de noeud de départ." });
      if (v.day_min && v.day_max && v.day_min > v.day_max) out.push({ level: "err", ...where, msg: "Jour minimum après le jour maximum." });
      scanConds(v.conditions, where);
      // atteignabilité
      const seen = new Set();
      const stack = [v.start];
      while (stack.length) {
        const id = stack.pop();
        if (!id || seen.has(id) || !v.nodes[id]) continue;
        seen.add(id);
        for (const o of GS.outputs(v.nodes[id])) stack.push(o.target);
      }
      let hasEnd = false;
      for (const [id, n] of Object.entries(v.nodes)) {
        const w = { visit: v.id, node: id };
        if (!seen.has(id)) out.push({ level: "warn", ...w, msg: "Noeud jamais atteint depuis le départ." });
        if (n.type === "end") hasEnd = true;
        if (n.type === "line") {
          if (!n.text || !n.text.trim()) out.push({ level: "warn", ...w, msg: "Réplique vide." });
          if (n.speaker !== GS.PLAYER && n.speaker !== GS.NARRATOR && !chars.has(n.speaker)) out.push({ level: "err", ...w, msg: "Locuteur inconnu : " + n.speaker });
          if (!n.next) out.push({ level: "warn", ...w, msg: "Réplique sans suite : le dialogue s'arrêtera ici." });
        }
        if (n.type === "choice") {
          if (!n.choices.length) out.push({ level: "err", ...w, msg: "Choix sans réponse." });
          n.choices.forEach((c, i) => {
            if (!c.next) out.push({ level: "warn", ...w, msg: "Réponse " + (i + 1) + " sans suite." });
            scanEffects(c.effects);
            scanConds(c.conditions, w);
          });
          if (n.choices.length && n.choices.every((c) => (c.conditions || []).length)) out.push({ level: "warn", ...w, msg: "Toutes les réponses ont des conditions : prévoir une réponse toujours disponible." });
        }
        if (n.type === "branch") {
          n.rules.forEach((r) => scanConds(r.conditions, w));
          if (!n.else) out.push({ level: "warn", ...w, msg: "Condition sans « sinon »." });
        }
        for (const o of GS.outputs(n)) if (o.target && !v.nodes[o.target]) out.push({ level: "err", ...w, msg: "Mène à un noeud qui n'existe pas : " + o.target });
        scanEffects(n.effects);
      }
      if (!hasEnd) out.push({ level: "warn", visit: v.id, msg: "Aucun noeud de fin." });
    }
    for (const [f, where] of flagsUsed) {
      if (!flagsSet.has(f)) out.push({ level: "warn", ...where, msg: "Le drapeau « " + f + " » est testé mais aucun choix ne le pose." });
    }
    return out;
  };

  GS.allFlags = function (story) {
    const set = new Set();
    const add = (effs) => (effs || []).forEach((e) => e.type === "flag" && set.add(e.flag));
    const addc = (conds) => (conds || []).forEach((c) => c.type === "flag" && set.add(c.flag));
    for (const v of story.visits) {
      addc(v.conditions);
      for (const n of Object.values(v.nodes)) {
        add(n.effects);
        (n.choices || []).forEach((c) => { add(c.effects); addc(c.conditions); });
        (n.rules || []).forEach((r) => addc(r.conditions));
      }
    }
    return [...set].sort();
  };

  // ------------------------------------------------------------------ simulation (mêmes règles que le jeu)
  GS.newState = function (story) {
    const aff = {};
    story.characters.forEach((c) => (aff[c.id] = +c.affection_start || 0));
    return { day: 1, affection: aff, flags: {}, visited: {}, coins: +(story.settings.start_coins || 0), items: {} };
  };

  const cmp = (a, op, b) => ({ ">=": a >= b, "<=": a <= b, ">": a > b, "<": a < b, "==": a === b, "!=": a !== b }[op]);

  GS.check = function (conds, st) {
    for (const c of conds || []) {
      if (c.type === "affection" && !cmp(+(st.affection[c.character] || 0), c.op, +c.value)) return false;
      if (c.type === "flag" && !!st.flags[c.flag] !== (c.is !== false)) return false;
      if (c.type === "day" && !cmp(+st.day, c.op, +c.value)) return false;
      if (c.type === "visited" && !!st.visited[c.visit] !== (c.is !== false)) return false;
      if (c.type === "item" && !cmp(+((st.items || {})[c.item] || 0), c.op, +c.value)) return false;
      if (c.type === "coins" && !cmp(+(st.coins || 0), c.op, +c.value)) return false;
    }
    return true;
  };

  GS.apply = function (effects, st, story) {
    const changes = [];
    for (const e of effects || []) {
      if (e.type === "affection" && +e.delta) {
        const c = story.characters.find((c) => c.id === e.character);
        const max = c ? +c.affection_max || 10 : 10;
        st.affection[e.character] = Math.max(-max, Math.min(max, (+st.affection[e.character] || 0) + +e.delta));
        changes.push(e);
      }
      if (e.type === "item" && +e.delta) {
        st.items = st.items || {};
        st.items[e.item] = Math.max(0, (+st.items[e.item] || 0) + +e.delta);
        changes.push(e);
      }
      if (e.type === "coins" && +e.delta) {
        st.coins = Math.max(0, (+st.coins || 0) + +e.delta);
        changes.push(e);
      }
      if (e.type === "flag") {
        if (e.value === false) delete st.flags[e.flag];
        else st.flags[e.flag] = true;
      }
    }
    return changes;
  };

  // Visites possibles un jour donné, triées comme le jeu (priorité), une par personnage.
  GS.eligibleVisits = function (story, st, day) {
    const out = [];
    for (const v of story.visits) {
      const why = [];
      if (v.day_min && day < v.day_min) why.push("trop tôt");
      if (v.day_max && day > v.day_max) why.push("trop tard");
      if (v.once && st.visited[v.id]) why.push("déjà jouée");
      if (!GS.check(v.conditions, Object.assign({}, st, { day }))) why.push("conditions non remplies");
      out.push({ visit: v, ok: !why.length, why });
    }
    return out;
  };
})();
