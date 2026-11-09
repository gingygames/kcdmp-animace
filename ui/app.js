// Galerie animaci pro KCD:MP - Klientska webova aplikace (CEF, ES5)
(function () {
  "use strict";

  var BLOK = 120, RH = 30, OTOCENI = 30;
  var rid = 0, cekaji = {};
  var rawData = window.__KATALOG || [];
  var rekvizitySeznam = window.__REKVIZITY || [];
  var nabytekSeznam = window.__NABYTEK || [];

  var KATEGORIE_INFO = [
    { id: "sezeni", nazev: "Sezení" },
    { id: "lezeni", nazev: "Ležení a spánek" },
    { id: "tanec", nazev: "Tanec" },
    { id: "jidlo", nazev: "Jídlo a pití" },
    { id: "hudba", nazev: "Hudba" },
    { id: "remesla", nazev: "Práce a řemesla" },
    { id: "boj", nazev: "Boj a zbraně" },
    { id: "kun", nazev: "Kůň, vůz a zvířata" },
    { id: "vira", nazev: "Víra" },
    { id: "zajeti", nazev: "Zajetí a tresty" },
    { id: "hospoda", nazev: "Hospoda a hry" },
    { id: "obchod", nazev: "Obchod a trh" },
    { id: "dvere", nazev: "Dveře, zámky a věci" },
    { id: "pece", nazev: "Mytí, péče a zranění" },
    { id: "gesta", nazev: "Gesta a emoce" },
    { id: "rozhovor", nazev: "Rozhovor a proslovy" },
    { id: "oblicej", nazev: "Obličej" },
    { id: "stani", nazev: "Stání a čekání" },
    { id: "pohyb", nazev: "Pohyb a plížení" },
    { id: "ukoly", nazev: "Úkoly (quest)" },
    { id: "ostatni", nazev: "Ostatní" },
  ];

  var PRIZNAKY = {
    C: "celé tělo", R: "rekvizita v pravé", L: "rekvizita v levé",
    M: "muž", F: "žena", S: "sedí", B: "leží", G: "na zemi",
    P: "dvojice", Q: "sekvence", O: "jednorázová"
  };

  var st = {
    dotaz: {},
    filtrovane: [],
    celkem: 0,
    sel: null,
    detail: null,
    stav: { telo: "figurina", pohlavi: "m", obleceni: "moje", zoom: "postava", klic: "", loop: false },
    props: [],
    nabytek: "",
    posun: { x: 0, y: -0.35, z: 0, yaw: 0 },
    partner: false,
    posunPartner: { x: 0, y: 0, z: 0, yaw: 0 },
    hlaseni: {},
    predvolby: {},
    spravce: true
  };

  var $ = function (id) { return document.getElementById(id); };

  function bezDiakritiky(s) {
    return String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  }

  // Komunikace se serverem KCD:MP
  function sendServer(op, data) {
    var payload = data || {};
    payload.op = op;
    payload.rid = ++rid;
    if (typeof KcdMp !== "undefined" && typeof KcdMp.emitServer === "function") {
      KcdMp.emitServer("animace.zadost", payload);
    } else if (window.__animaceDev) {
      window.__animaceDev("animace.zadost", payload);
    }
    return payload.rid;
  }

  function zadost(op, data, cb) {
    var id = sendServer(op, data);
    if (cb) cekaji[id] = cb;
  }

  function akce(op, data, hotovo) {
    zadost(op, data, function (o) {
      if (o && o.ok === false) return toast(o.chyba || "chyba", true);
      if (o && o.zprava) toast(o.zprava);
      if (hotovo) hotovo(o);
    });
  }

  // Příjem zpráv od KCD:MP
  if (typeof KcdMp !== "undefined" && typeof KcdMp.onMessage === "function") {
    KcdMp.onMessage(function (msg) {
      zpracujZpravu(msg);
    });
  } else {
    window.addEventListener("message", function (e) {
      if (e.data) zpracujZpravu(e.data);
    });
  }

  function zpracujZpravu(msg) {
    if (!msg) return;
    if (msg.op === "vysledek" && msg.vysledek) {
      var o = msg.vysledek;
      var cb = cekaji[o.rid];
      delete cekaji[o.rid];
      if (cb) cb(o);
      else if (o.ok === false && o.chyba) toast(o.chyba, true);
    } else if (msg.op === "otevrit") {
      if (msg.q) {
        $("q").value = msg.q;
        st.dotaz.q = msg.q;
      }
      if (msg.stav) {
        for (var k in msg.stav) st.stav[k] = msg.stav[k];
        synchronizujStavUI();
      }
      hledej();
    } else if (msg.op === "stav") {
      st.stav.klic = msg.klic || "";
      st.stav.loop = msg.loop || false;
      var hrajeEl = $("hraje");
      if (hrajeEl) {
        hrajeEl.textContent = st.stav.klic ? (st.stav.loop ? "⟳ " : "▶ ") + st.stav.klic : "";
      }
      kresliDetail();
    }
  }

  var h = function (tag, props) {
    var el = document.createElement(tag);
    for (var k in props || {}) {
      var v = props[k];
      if (v === undefined || v === null || v === false) continue;
      if (k === "text") el.textContent = v;
      else if (k === "class") el.className = v;
      else if (k === "value") el.value = v;
      else if (k.slice(0, 2) === "on") el.addEventListener(k.slice(2), v);
      else el.setAttribute(k, v === true ? "" : v);
    }
    for (var i = 2; i < arguments.length; i++) {
      if (arguments[i]) {
        el.appendChild(typeof arguments[i] === "string" ? document.createTextNode(arguments[i]) : arguments[i]);
      }
    }
    return el;
  };

  function toast(t, err) {
    if (window.Kit) Kit.toast(String(t || ""), err ? "err" : "ok");
    else console.log((err ? "ERR: " : "OK: ") + t);
  }

  function kopirovat(text, co) {
    var ta = h("textarea", { style: "position:fixed;left:-9999px;top:0" });
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
    document.body.removeChild(ta);
    toast(ok ? "Zkopírováno: " + co : "Schránka nedostupná, opiš ručně.", !ok);
  }

  // ---------------------------------------------------------------------------
  // Vyhledávání a virtuální seznam
  // ---------------------------------------------------------------------------

  function hledej() {
    var qTokens = bezDiakritiky(st.dotaz.q || "").split(/\s+/).filter(Boolean);
    var kat = st.dotaz.kat;
    var pohlavi = st.dotaz.pohlavi;
    var telo = st.dotaz.telo;
    var smycka = st.dotaz.smycka;
    var rekvizita = st.dotaz.rekvizita;
    var prostredi = st.dotaz.prostredi;
    var sekvence = st.dotaz.sekvence;
    var dvojice = st.dotaz.dvojice;

    var poctyKat = {};
    var vysledky = [];

    for (var i = 0; i < rawData.length; i++) {
      var r = rawData[i];
      // Indexy: 0: klic, 1: fragment, 2: tags, 3: kat, 4: priznaky, 5: duration, 6: clip, 7: sequence, 8: props, 9: postoj, 10: dvojice, 11: posunPartner
      var klic = r[0], frag = r[1], tags = r[2], rKat = r[3], prz = r[4];

      if (qTokens.length > 0) {
        var textKlic = bezDiakritiky(klic + " " + rKat + " " + r[7]);
        var matchAll = true;
        for (var t = 0; t < qTokens.length; t++) {
          if (textKlic.indexOf(qTokens[t]) === -1) { matchAll = false; break; }
        }
        if (!matchAll) continue;
      }

      if (pohlavi === "m" && prz.indexOf("M") === -1) continue;
      if (pohlavi === "f" && prz.indexOf("F") === -1) continue;
      if (telo === "cele" && prz.indexOf("C") === -1) continue;
      if (telo === "horni" && prz.indexOf("C") !== -1) continue;
      if (smycka === "smycka" && prz.indexOf("O") !== -1) continue;
      if (smycka === "jednou" && prz.indexOf("O") === -1) continue;
      if (rekvizita && prz.indexOf("R") === -1 && prz.indexOf("L") === -1) continue;
      if (prostredi && prz.indexOf("S") === -1 && prz.indexOf("B") === -1) continue;
      if (sekvence && prz.indexOf("Q") === -1) continue;
      if (dvojice && prz.indexOf("P") === -1) continue;

      poctyKat[rKat] = (poctyKat[rKat] || 0) + 1;
      if (kat && rKat !== kat) continue;

      vysledky.push(r);
    }

    st.filtrovane = vysledky;
    st.celkem = vysledky.length;
    $("stav").textContent = st.celkem.toLocaleString("cs-CZ") + " animací";

    kresliKategorie(poctyKat);
    $("seznam").scrollTop = 0;
    kresliSeznam();
  }

  function kresliKategorie(pocty) {
    var box = $("kat");
    box.replaceChildren();
    KATEGORIE_INFO.forEach(function (k) {
      var pocet = pocty[k.id] || 0;
      var chip = h("button", {
        class: "k-chip" + (st.dotaz.kat === k.id ? " k-chip--sel" : "") + (pocet === 0 ? " k-chip--empty" : ""),
        text: k.nazev + " (" + pocet + ")",
        onclick: function () {
          st.dotaz.kat = (st.dotaz.kat === k.id) ? "" : k.id;
          hledej();
        }
      });
      box.appendChild(chip);
    });
  }

  function kresliSeznam() {
    var g = $("seznam");
    $("spacer").style.height = st.celkem * RH + "px";
    var r0 = Math.max(0, Math.floor(g.scrollTop / RH) - 4);
    var r1 = Math.min(st.celkem, r0 + Math.ceil(g.clientHeight / RH) + 8);
    var box = $("rows");
    box.style.transform = "translateY(" + (r0 * RH) + "px)";
    box.replaceChildren();

    for (var i = r0; i < r1; i++) {
      var d = st.filtrovane[i];
      if (!d) continue;
      var klic = d[0], frag = d[1], tags = d[2], prz = d[4], dur = d[5];
      var jeVybrany = (st.sel && st.sel[0] === klic);
      var jeAktivni = (st.stav.klic === klic);

      var row = h("div", {
        class: "row" + (jeVybrany ? " row--sel" : "") + (jeAktivni ? " row--hrana" : ""),
        dataset: { klic: klic, idx: String(i) },
        onclick: function () {
          var idx = Number(this.dataset.idx);
          vyberAnimaci(st.filtrovane[idx]);
        },
        ondblclick: function () {
          var idx = Number(this.dataset.idx);
          var anim = st.filtrovane[idx];
          vyberAnimaci(anim);
          akce("hrat", { klic: anim[0], loop: true });
        }
      });

      row.appendChild(h("span", { class: "f", text: frag }));
      if (tags) row.appendChild(h("span", { class: "t", text: tags }));
      row.appendChild(h("span", { class: "p", text: prz }));
      row.appendChild(h("span", { class: "d", text: dur ? dur + "s" : "" }));

      box.appendChild(row);
    }
  }

  function vyberAnimaci(animRec) {
    if (!animRec) return;
    st.sel = animRec;
    st.props = animRec[8] ? JSON.parse(JSON.stringify(animRec[8])) : [];
    st.partner = (animRec[10] !== null);
    if (animRec[11]) st.posunPartner = JSON.parse(JSON.stringify(animRec[11]));

    kresliSeznam();
    kresliDetail();
  }

  function kresliDetail() {
    var box = $("detail");
    box.replaceChildren();
    var d = st.sel;
    if (!d) {
      box.appendChild(h("div", { class: "k-empty", text: "Vyber animaci ze seznamu vlevo." }));
      return;
    }

    var klic = d[0], frag = d[1], tags = d[2], dur = d[5], prz = d[4], sq = d[7];
    var hrajeTady = (st.stav.klic === klic);

    box.appendChild(h("h3", { text: frag }));
    if (tags) box.appendChild(h("div", { class: "k-muted", text: "Tagy: " + tags }));
    box.appendChild(h("div", { class: "k-muted", text: "Délka: " + dur + "s | Příznaky: " + prz }));
    if (sq) box.appendChild(h("div", { class: "k-muted", text: "Sekvence: " + sq }));

    // Tlačítka přehrávání
    var tlacBox = h("div", { class: "tlac" });
    tlacBox.appendChild(h("button", {
      class: "k-btn k-btn--sm",
      text: "▶ Jednou",
      onclick: function () { akce("hrat", { klic: klic, loop: false }); }
    }));
    tlacBox.appendChild(h("button", {
      class: "k-btn k-btn--sm",
      text: "⟳ Smyčka",
      onclick: function () { akce("hrat", { klic: klic, loop: true }); }
    }));
    tlacBox.appendChild(h("button", {
      class: "k-btn k-btn--ghost k-btn--sm",
      text: "■ Stop",
      onclick: function () { akce("zastavit"); }
    }));
    box.appendChild(tlacBox);

    // Rekvizity
    box.appendChild(h("h4", { text: "Rekvizity v rukou" }));
    if (st.props && st.props.length) {
      st.props.forEach(function (p) {
        box.appendChild(h("div", { class: "k-muted", text: (p.hand === "left" ? "Levá: " : "Pravá: ") + (p.item || p.model) }));
      });
    } else {
      box.appendChild(h("div", { class: "k-muted", text: "Bez rekvizit." }));
    }

    // Partner
    if (d[10]) {
      box.appendChild(h("h4", { text: "Partner (Dvojice)" }));
      box.appendChild(h("div", { class: "k-muted", text: "Partner: " + d[10].klic + " (zdroj: " + d[10].zdroj + ")" }));
      box.appendChild(h("div", { class: "k-muted", text: "Při přehrání se spustí obě postavy synchronně po usazení (600 ms)." }));
    }

    // Hlášení chyb
    box.appendChild(h("h4", { text: "Hlášení funkčnosti" }));
    var hBox = h("div", { class: "tlac" });
    hBox.appendChild(h("button", {
      class: "k-btn k-btn--ghost k-btn--sm",
      text: "✗ Nefunguje",
      onclick: function () {
        var pozn = prompt("Proč animace nefunguje? (volitelné)");
        if (pozn !== null) akce("hlasit", { klic: klic, stav: "nefunguje", pozn: pozn });
      }
    }));
    hBox.appendChild(h("button", {
      class: "k-btn k-btn--ghost k-btn--sm",
      text: "✓ Funguje",
      onclick: function () {
        akce("hlasit", { klic: klic, stav: "ok", pozn: "" });
      }
    }));
    box.appendChild(hBox);

    // Správce - uložení předvolby
    if (st.spravce) {
      box.appendChild(h("h4", { text: "Správce" }));
      var sBox = h("div", { class: "tlac" });
      sBox.appendChild(h("button", {
        class: "k-btn k-btn--sm",
        text: "Uložit jako výchozí předvolbu",
        onclick: function () {
          akce("ulozitPredvolbu", { klic: klic, props: st.props, posunPartner: st.posunPartner });
        }
      }));
      box.appendChild(sBox);
    }
  }

  function synchronizujStavUI() {
    // Synchronizace tabů v záhlaví
    document.querySelectorAll("[data-telo]").forEach(function (btn) {
      btn.setAttribute("aria-selected", String(btn.dataset.telo === st.stav.telo));
    });
    document.querySelectorAll("[data-pohlavi]").forEach(function (btn) {
      btn.setAttribute("aria-selected", String(btn.dataset.pohlavi === st.stav.pohlavi));
    });
    document.querySelectorAll("[data-zoom]").forEach(function (btn) {
      btn.setAttribute("aria-selected", String(btn.dataset.zoom === st.stav.zoom));
    });
  }

  // ---------------------------------------------------------------------------
  // Události prvků formuláře a klávesnice
  // ---------------------------------------------------------------------------

  function inicializujOvladace() {
    $("seznam").addEventListener("scroll", kresliSeznam);

    $("q").addEventListener("input", function () {
      st.dotaz.q = this.value;
      hledej();
    });

    $("fPohlavi").addEventListener("change", function () { st.dotaz.pohlavi = this.value; hledej(); });
    $("fTelo").addEventListener("change", function () { st.dotaz.telo = this.value; hledej(); });
    $("fSmycka").addEventListener("change", function () { st.dotaz.smycka = this.value; hledej(); });
    $("fRekvizita").addEventListener("change", function () { st.dotaz.rekvizita = this.checked; hledej(); });
    $("fProstredi").addEventListener("change", function () { st.dotaz.prostredi = this.checked; hledej(); });
    $("fSekvence").addEventListener("change", function () { st.dotaz.sekvence = this.checked; hledej(); });
    $("fDvojice").addEventListener("change", function () { st.dotaz.dvojice = this.checked; hledej(); });

    // Přepínání těla
    document.querySelectorAll("[data-telo]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        st.stav.telo = this.dataset.telo;
        synchronizujStavUI();
        akce("telo", { telo: st.stav.telo });
      });
    });

    // Přepínání pohlaví
    document.querySelectorAll("[data-pohlavi]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        st.stav.pohlavi = this.dataset.pohlavi;
        synchronizujStavUI();
        akce("pohlavi", { pohlavi: st.stav.pohlavi });
      });
    });

    // Zoom presety
    document.querySelectorAll("[data-zoom]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        st.stav.zoom = this.dataset.zoom;
        synchronizujStavUI();
        akce("zoom", { zoom: st.stav.zoom });
      });
    });

    // Otáčení
    $("vlevo").addEventListener("click", function () { akce("otocit", { uhel: -OTOCENI }); });
    $("vpravo").addEventListener("click", function () { akce("otocit", { uhel: OTOCENI }); });

    // Zavřít
    $("zavrit").addEventListener("click", function () { akce("zavrit"); });

    // Klávesnice
    window.addEventListener("keydown", function (e) {
      if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT" || e.target.tagName === "TEXTAREA") return;
      if (e.key === "Escape") { akce("zavrit"); }
      else if (e.key === "q" || e.key === "Q") { akce("otocit", { uhel: -OTOCENI }); }
      else if (e.key === "e" || e.key === "E") { akce("otocit", { uhel: OTOCENI }); }
      else if (e.key === "s" || e.key === "S") { akce("zastavit"); }
      else if (e.key === " " && st.sel) { e.preventDefault(); akce("hrat", { klic: st.sel[0], loop: false }); }
      else if (e.key === "Enter" && st.sel) { e.preventDefault(); akce("hrat", { klic: st.sel[0], loop: true }); }
    });
  }

  inicializujOvladace();
  hledej();
})();
