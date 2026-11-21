// Element Handoff's pick mode, injected into a Browser Pane's page with
// `kb ctl -i ID eval` (pick.lua). One expression: it turns pick mode on, or off
// if it is already on, and returns "started" or "cancelled". pick.lua wraps it
// in `(stayOn => …)(true|false)`: with stayOn a pick leaves pick mode on, for
// the next one; without it the first pick ends pick mode.
//
// While on, the element under the pointer is outlined the way kb's own Inspect
// does it (margin, border, padding, content and a label), in a layer that
// ignores the mouse. Capture listeners on window take the press and click that
// pick, so the page never sees them; the wheel still scrolls. Esc cancels.
//
// An empty layer drawn over its parent (a ripple, a link overlay) gives way to
// that parent, so hovering YouTube's Subscribe outlines the button, not its
// ripple. ↑ outlines the parent of what is outlined, ↓ goes back toward the
// element under the pointer.
//
// pick-wait.sh then calls globalThis.__trexPick.wait(ms) in a loop. It resolves
// to "picked\n" + the description as a JSON string + "\n" + the description
// (once per pick: with stayOn, picks made between waits queue up),
// "cancelled", or "pending" when `ms` passes
// first (kb gives up on a request after 30 s, so each wait is shorter). If no
// wait comes for LEASE ms, the waiter is gone and pick mode ends by itself.
(() => {
  const LEASE = 90000;
  const HTML_MAX = 300;      // the html line
  const TEXT_MAX = 80;       // the text line
  const ATTR_MAX = 60;       // each attribute value in the html line
  const COMPONENTS = 3;      // web components in the in line
  const REACT_MAX = 5;       // React components in the react line
  const SOURCE_BUDGET = 2000; // ms a click waits for a React source location
  const ROOT_ID = '__trex_pick';

  const previous = globalThis.__trexPick;
  if (previous && previous.active()) { previous.cancel(); return 'cancelled'; }
  // A pick that just ended still swallows the rest of its click for a second;
  // its listeners come first, so they would swallow this pick's click too.
  if (previous && previous.release) previous.release();

  // The element at a point, inside open shadow roots too.
  const at = (x, y) => {
    let e = document.elementFromPoint(x, y);
    while (e && e.shadowRoot) {
      const inner = e.shadowRoot.elementFromPoint(x, y);
      if (!inner || inner === e) break;
      e = inner;
    }
    return e;
  };

  const parentOf = e => e.parentElement || (e.getRootNode() instanceof ShadowRoot ? e.getRootNode().host : null);

  // Whether `e` shows nothing of its own: no text, no media, no background
  // image, and no shadow root (whose content textContent doesn't see).
  const MEDIA = 'img,svg,video,canvas,picture,iframe,object,embed,input,select,textarea';
  const hollow = e => !e.shadowRoot && !(e.textContent || '').trim() && !e.matches(MEDIA) &&
    !e.querySelector(MEDIA) && getComputedStyle(e).backgroundImage === 'none';
  // Whether `e` covers at least half of `p`.
  const covers = (e, p) => {
    const a = e.getBoundingClientRect(), b = p.getBoundingClientRect();
    return b.width * b.height > 0 && a.width * a.height >= 0.5 * b.width * b.height;
  };

  // The element a pick at a point means: the one there, or, while that is a
  // hollow layer over its parent, the parent.
  const target = (x, y) => {
    let e = at(x, y);
    while (e && hollow(e)) {
      const p = parentOf(e);
      if (!p || p === document.body || p === document.documentElement || !covers(e, p)) break;
      e = p;
    }
    return e;
  };

  // --- the outline -----------------------------------------------------------

  const root = document.createElement('div');
  root.id = ROOT_ID;
  root.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:2147483647';
  for (let i = 0; i < 6; i++) root.appendChild(document.createElement('div'));
  const [margin, border, padding, content, label, hint] = root.children;
  const tag = 'background:#202124;color:#e8eaed;font:12px/20px ui-monospace,Menlo,monospace;padding:0 6px;' +
    'border-radius:3px;white-space:nowrap;max-width:90vw;overflow:hidden;text-overflow:ellipsis';
  hint.style.cssText = 'position:fixed;right:8px;bottom:8px;' + tag;
  hint.textContent = 'Pick an element for the agent · ↑ ↓ parent, child · Esc cancels';
  document.documentElement.appendChild(root);

  const px = v => Math.max(0, parseFloat(v) || 0);
  const box = (el, left, top, w, h, edge, color) => {
    el.style.cssText = 'position:fixed;box-sizing:content-box;left:' + left + 'px;top:' + top + 'px;' +
      'width:' + Math.max(0, w) + 'px;height:' + Math.max(0, h) + 'px;border-style:solid;' +
      'border-color:' + color + ';border-width:' + edge.map(v => v + 'px').join(' ');
  };
  const short = e => e.localName + (e.id ? '#' + e.id : '') + [...e.classList].slice(0, 3).map(c => '.' + c).join('');

  let shown = null;
  const outline = e => {
    shown = e;
    const r = e.getBoundingClientRect(), s = getComputedStyle(e);
    const sides = what => ['Top', 'Right', 'Bottom', 'Left'].map(k => px(s[what.replace('*', k)]));
    const m = sides('margin*'), b = sides('border*Width'), p = sides('padding*');
    const innerW = r.width - b[1] - b[3] - p[1] - p[3], innerH = r.height - b[0] - b[2] - p[0] - p[2];
    box(margin, r.left - m[3], r.top - m[0], r.width, r.height, m, 'rgba(246,178,107,.66)');
    box(border, r.left, r.top, r.width - b[1] - b[3], r.height - b[0] - b[2], b, 'rgba(255,229,153,.66)');
    box(padding, r.left + b[3], r.top + b[0], innerW, innerH, p, 'rgba(147,196,125,.55)');
    box(content, r.left + b[3] + p[3], r.top + b[0] + p[0], innerW, innerH, [0, 0, 0, 0], 'transparent');
    content.style.background = 'rgba(111,168,220,.66)';
    label.textContent = short(e) + '  ' + Math.round(r.width) + ' × ' + Math.round(r.height);
    const top = r.top - m[0] > 24 ? r.top - m[0] - 22 : Math.min(innerHeight - 22, r.bottom + m[2] + 4);
    label.style.cssText = 'position:fixed;left:' + Math.max(0, Math.min(r.left, innerWidth - 200)) + 'px;top:' + top + 'px;' + tag;
  };

  // --- the description ---------------------------------------------------------

  // A selector for `el`, as kb's Inspect builds it: tag names with
  // :nth-of-type where needed, from the nearest unique id (or body) down.
  const selector = el => {
    const path = [];
    for (let e = el; e && e.nodeType === 1; e = e.parentElement) {
      const root = e.getRootNode();
      if (e.id && root.querySelectorAll('#' + CSS.escape(e.id)).length === 1) { path.unshift('#' + CSS.escape(e.id)); break; }
      const same = e.parentElement ? [...e.parentElement.children].filter(c => c.localName === e.localName) : [];
      path.unshift(e.localName + (same.length > 1 ? ':nth-of-type(' + (same.indexOf(e) + 1) + ')' : ''));
      if (e.localName === 'body') break;
    }
    return path.join(' > ');
  };

  const cut = (text, max) => text.length > max ? text.slice(0, max - 1) + '…' : text;

  // The opening tag as the page has it, made short: the first three classes,
  // and any other attribute value cut at ATTR_MAX characters.
  const openingTag = el => {
    const attrs = [...el.attributes].map(a => {
      let value = a.value;
      if (a.name === 'class') {
        const classes = value.split(/\s+/).filter(Boolean);
        value = classes.slice(0, 3).join(' ') + (classes.length > 3 ? ' …' : '');
      } else {
        value = cut(value, ATTR_MAX);
      }
      return ' ' + a.name + '="' + value.replace(/&/g, '&amp;').replace(/"/g, '&quot;') + '"';
    });
    return '<' + el.localName + attrs.join('') + '>';
  };

  // The web components (custom elements, named with a "-") around `el`,
  // nearest first, across shadow roots: on a site built from them, such as
  // YouTube, these are its components.
  const components = el => {
    const found = [];
    for (let e = parentOf(el); e && found.length < COMPONENTS; e = parentOf(e)) {
      if (e.localName.includes('-')) found.push('<' + e.localName + '>');
    }
    return found;
  };

  // `react`: { names, source } from reactOf(), or null for an element React
  // didn't render.
  const describe = (el, react) => {
    const attrs = [];
    if (el.id) attrs.push('id="' + el.id + '"');
    const classes = [...el.classList].slice(0, 3);
    if (classes.length) attrs.push('class="' + classes.join(' ') + '"');
    let first = '<' + el.localName + attrs.map(a => ' ' + a).join('') + '>';
    if (react && react.names.length) first += ' in <' + react.names[0] + '>';
    if (react && react.source) first += ' at ' + react.source;

    const r = el.getBoundingClientRect(), n = Math.round;
    const text = (el.innerText ?? el.textContent ?? '').replace(/\s+/g, ' ').trim();
    // A void element (img, input) has no closing tag.
    const close = '</' + el.localName + '>';
    const html = el.cloneNode(false).outerHTML.endsWith(close) ? openingTag(el) + text + close : openingTag(el);
    const around = components(el);

    return [
      first,
      ...(around.length ? ['in: ' + around.join(' in ')] : []),
      'page: ' + location.href,
      'path: ' + selector(el),
      'box: ' + n(r.width) + '×' + n(r.height) + ' at ' + n(r.left + scrollX) + ',' + n(r.top + scrollY) + ' (page px)',
      ...(text ? ['text: ' + cut(text, TEXT_MAX)] : []),
      'html: ' + cut(html, HTML_MAX),
      ...(react && react.names.length ? ['react: ' + react.names.join(' ← ')] : []),
    ].join('\n');
  };

  // --- React -------------------------------------------------------------------
  //
  // Read from the element when it is picked (React keeps its fiber on the DOM
  // node as __reactFiber$<random>), so any open page works without setup.
  // Where the element's JSX is written: React 18 and earlier keep it in
  // development as fiber._debugSource; React 19 keeps fiber._debugStack, an
  // Error whose first frame outside React is that JSX, in the bundle, which
  // its source map turns into the source file and line.

  const fiberOf = el => {
    for (let e = el; e; e = parentOf(e)) {
      const key = Object.keys(e).find(k => k.startsWith('__reactFiber$'));
      if (key) return e[key];
    }
    return null;
  };

  // Function, class (and React 18's indeterminate), forwardRef, memo and simple memo.
  const COMPONENT_TAGS = new Set([0, 1, 2, 11, 14, 15]);
  const nameOf = t => (t && (t.displayName || t.name ||
    (t.render && (t.render.displayName || t.render.name)) || (t.type && nameOf(t.type)))) || 'Anonymous';

  // The components that rendered `fiber`, innermost first. In development,
  // owners: who rendered whom, Server Components included (an owner is then
  // { name, env: "Server", owner }), framework wrappers such as Next.js's
  // routers left out. Without owners (production), the components above it.
  const componentsOf = fiber => {
    const names = [];
    const add = name => { if (name && names[names.length - 1] !== name) names.push(name); }; // memo(X) wraps X: one name
    for (let o = fiber._debugOwner; o && names.length < REACT_MAX; o = o.tag !== undefined ? o._debugOwner : o.owner) {
      add(o.tag !== undefined ? (COMPONENT_TAGS.has(o.tag) ? nameOf(o.type) : null) : o.name);
    }
    if (names.length) return names;
    for (let f = fiber; f && names.length < REACT_MAX; f = f.return) {
      if (COMPONENT_TAGS.has(f.tag)) add(nameOf(f.type));
    }
    return names;
  };

  // A source path for people: the dev server's own path for a file it serves,
  // the project path inside webpack:// and turbopack:// URLs.
  const sourcePath = (source, base, sourceRoot) => {
    if (/^webpack:\/\//.test(source)) return source.replace(/^webpack:\/\/[^/]*\//, '').replace(/^\.\//, '').replace(/\?.*$/, '');
    // turbopack:///[project]/app/page.js [app-rsc] (ecmascript)
    if (/^turbopack:\/\//.test(source)) return source.replace(/^turbopack:\/\/\/(\[project\]\/)?/, '').replace(/ \[.*$/, '');
    let url;
    try { url = new URL((sourceRoot ? sourceRoot.replace(/\/?$/, '/') : '') + source, base); } catch { return source; }
    if (url.protocol === 'file:') return decodeURIComponent(url.pathname);
    if (url.origin === location.origin) return decodeURIComponent(url.pathname).replace(/^\/@fs\//, '/').replace(/^\//, '');
    return url.href;
  };

  const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  // A source map's mappings, as one array per generated line of
  // [generated column, source, original line, original column] (0-based).
  const decode = mappings => {
    const lines = [];
    let source = 0, line = 0, column = 0;
    for (const text of mappings.split(';')) {
      const segments = [];
      let generated = 0;
      for (const segment of text.split(',')) {
        if (!segment) continue;
        const values = [];
        let value = 0, shift = 0;
        for (const ch of segment) {
          const digit = B64.indexOf(ch);
          value += (digit & 31) * 2 ** shift;
          if (digit & 32) { shift += 5; continue; }
          values.push(value % 2 ? -(value - 1) / 2 : value / 2);
          value = 0; shift = 0;
        }
        generated += values[0];
        if (values.length >= 4) {
          source += values[1]; line += values[2]; column += values[3];
          segments.push([generated, source, line, column]);
        }
      }
      lines.push(segments);
    }
    return lines;
  };

  // The original "path:line:column" of 0-based `line`, `column` in a map whose
  // sources resolve against `base`; null if it has no mapping there. Index maps
  // (sections, as Turbopack writes) are followed into the section that holds it.
  const original = (map, base, line, column) => {
    if (map.sections) {
      let section = null;
      for (const s of map.sections) {
        const o = s.offset;
        if (o.line < line || (o.line === line && o.column <= column)) section = s; else break;
      }
      if (!section || !section.map) return null;
      const o = section.offset;
      return original(section.map, base, line - o.line, o.line === line ? column - o.column : column);
    }
    map.decoded = map.decoded || decode(map.mappings || '');
    let hit = null;
    for (const segment of map.decoded[line] || []) { if (segment[0] <= column) hit = segment; else break; }
    if (!hit || map.sources[hit[1]] == null) return null;
    return sourcePath(map.sources[hit[1]], base, map.sourceRoot) + ':' + (hit[2] + 1) + ':' + (hit[3] + 1);
  };

  // The source map of a script: { map, base } or null. A script the page can
  // fetch names its map (sourceMappingURL). One it can't (webpack-internal:, a
  // server file in a Next.js stack) may still have one from Next.js's dev
  // server, as React's own dev tools get it. Fetched again for each pick: hot
  // reload changes code under the same URL, so a map kept longer goes stale.
  const maps = new Map();
  const mapOf = script => {
    if (!maps.has(script)) {
      maps.set(script, (async () => {
        if (/^https?:/.test(script)) {
          const code = await (await fetch(script)).text();
          const found = [...code.matchAll(/\/\/[#@] sourceMappingURL=(\S+)/g)].pop();
          if (!found) return null;
          const url = new URL(found[1], script);
          return { map: await (await fetch(url)).json(), base: url.protocol === 'data:' ? script : url.href };
        }
        const r = await fetch('/__nextjs_source-map?filename=' + encodeURIComponent(script));
        return r.ok ? { map: await r.json(), base: script } : null;
      })().catch(() => null));
    }
    return maps.get(script);
  };

  // Frames that are React's or a library's, not where the JSX is written.
  const INTERNAL = /jsxDEV|jsx-dev-runtime|react-stack-|fakeJSXCallSite|\/node_modules\/|\.vite\/deps\//;

  // Where the JSX of `fiber` is written, as "path:line:column" (or "path" when
  // only the file is known); null if React kept no source.
  const sourceOf = async fiber => {
    const s = fiber._debugSource;
    if (s && s.fileName) return s.fileName + (s.lineNumber ? ':' + s.lineNumber + (s.columnNumber ? ':' + s.columnNumber : '') : '');
    const stack = fiber._debugStack && fiber._debugStack.stack;
    if (!stack) return null;
    for (const line of stack.split('\n').slice(1)) {
      const m = line.match(/at (?:(.*?) \()?(.+?):(\d+):(\d+)\)?\s*$/);
      if (!m || INTERNAL.test(line)) continue;
      // A Server Component's frame: rsc://React/Server/<its file>?<n>
      const script = m[2].replace(/^rsc:\/\/React\/Server\//, '').replace(/\?\d+$/, '');
      const found = await mapOf(script);
      const at = found && original(found.map, found.base, +m[3] - 1, +m[4] - 1);
      if (at && !/node_modules\//.test(at)) return at;
      if (at) continue;
      // webpack's eval'd modules name their file even without a map.
      if (script.startsWith('webpack-internal:')) {
        const file = script.replace(/^webpack-internal:\/\/\/(\([^)]*\)\/)?/, '').replace(/^\.\//, '').replace(/\?.*$/, '');
        if (!file.includes('node_modules/')) return file;
      }
    }
    return null;
  };

  // { names, source } for an element React rendered, waiting at most
  // SOURCE_BUDGET ms for the source; null for one it didn't.
  // `slow` is set when the source was left out for taking too long.
  let slow = false;
  const reactOf = async el => {
    const fiber = fiberOf(el);
    if (!fiber) return null;
    const names = componentsOf(fiber);
    let timer;
    const timeout = new Promise(resolve => { timer = setTimeout(() => { slow = true; resolve(null); }, SOURCE_BUDGET); });
    const source = await Promise.race([sourceOf(fiber).catch(() => null), timeout]);
    clearTimeout(timer);
    return { names, source };
  };

  // --- listeners ---------------------------------------------------------------

  let result = null;        // "picked\n…" or "cancelled" once pick mode ends
  let wake = null;          // resolves the pending wait()
  const queued = [];        // picks (with stayOn) no wait() has taken yet
  let lease = null;
  let swallowUntil = 0;     // after a pick, the rest of that click is swallowed too
  let looking = false;      // a pick is waiting for its React source
  let pressed = false;      // this press already picked (its pointerdown; the mousedown that follows is the same press)
  let frame = 0, lastX = 0, lastY = 0;
  let base = null;          // target() under the pointer
  let current = null;       // what is outlined and a click picks: base, or an ancestor chosen with ↑

  const stop = e => { e.preventDefault(); e.stopImmediatePropagation(); };

  // What wait() gives pick-wait.sh for a pick: the description as a JSON
  // string (one line, for the paste it sends Rex), then as text (to copy).
  const picked = description => 'picked\n' + JSON.stringify(description + '\n') + '\n' + description;

  // A pick is done: ends pick mode, or with stayOn hands the pick to the waiter
  // and goes on picking.
  const hand = (el, description) => {
    if (result !== null) return;
    if (!stayOn) return finish(picked(description));
    looking = false;
    outline(el);
    if (wake) { wake(picked(description)); wake = null; } else queued.push(picked(description));
  };

  const release = () => { for (const [type, fn] of clicking) removeEventListener(type, fn, true); };

  const finish = value => {
    if (result !== null) return;
    result = value;
    root.remove();
    clearTimeout(lease);
    for (const [type, fn] of pointing) removeEventListener(type, fn, true);
    // The press that picked is followed by its release and click, and a
    // double click by a second press: keep swallowing those, then let go.
    setTimeout(release, 1000);
    if (wake) { wake(value); wake = null; }
  };

  const onMove = e => {
    if (looking) return;
    lastX = e.clientX; lastY = e.clientY;
    if (frame) return;
    frame = requestAnimationFrame(() => {
      frame = 0;
      const el = target(lastX, lastY);
      // A pointer that stays on the same element keeps what ↑ chose.
      if (!el || root.contains(el) || el === base) return;
      base = current = el;
      outline(el);
    });
  };

  // ↑: the parent of what is outlined. ↓: its child on the way to the element
  // under the pointer.
  const climb = up => {
    if (!current) return;
    let next = null;
    if (up) {
      const p = parentOf(current);
      if (p && p !== document.documentElement) next = p;
    } else {
      for (let e = at(lastX, lastY); e && e !== current; e = parentOf(e)) {
        if (parentOf(e) === current) { next = e; break; }
      }
    }
    if (next) { current = next; outline(next); }
  };

  const onPress = e => {
    if (result !== null) { if (performance.now() < swallowUntil) stop(e); return; }
    stop(e);
    if (e.button !== 0 || looking || pressed) return;
    pressed = true;
    let el = current;
    if (el) {
      const r = el.getBoundingClientRect();
      if (e.clientX < r.left || e.clientX > r.right || e.clientY < r.top || e.clientY > r.bottom) el = null;
    }
    el = el || target(e.clientX, e.clientY) || shown;
    if (!el) { pressed = false; return; }
    outline(el);
    swallowUntil = performance.now() + 1000;
    looking = true;
    label.textContent = 'Finding source…';
    reactOf(el).then(react => hand(el, describe(el, react)),
      () => hand(el, describe(el, null)));
  };

  const onRest = e => {
    if (e.type === 'pointerup' || e.type === 'mouseup') pressed = false;
    if (result === null || performance.now() < swallowUntil) stop(e);
  };

  const onKey = e => {
    if (e.key === 'Escape') { stop(e); finish('cancelled'); }
    else if ((e.key === 'ArrowUp' || e.key === 'ArrowDown') && !looking) { stop(e); climb(e.key === 'ArrowUp'); }
  };

  // Removed as soon as pick mode ends.
  const pointing = [['pointermove', onMove], ['keydown', onKey]];
  // Kept a second longer, to swallow the rest of the click that picked.
  const clicking = [
    ['pointerdown', onPress], ['mousedown', onPress],
    ...['pointerup', 'mouseup', 'click', 'dblclick', 'auxclick', 'contextmenu'].map(type => [type, onRest]),
  ];
  for (const [type, fn] of [...pointing, ...clicking]) addEventListener(type, fn, true);

  const renew = () => { clearTimeout(lease); lease = setTimeout(() => finish('cancelled'), LEASE); };
  renew();

  globalThis.__trexPick = {
    active: () => result === null,
    cancel: () => finish('cancelled'),
    release,
    wait: ms => {
      if (queued.length) return Promise.resolve(queued.shift());
      if (result !== null) return Promise.resolve(result);
      renew();
      return new Promise(resolve => {
        wake = resolve;
        setTimeout(() => { if (wake === resolve) { wake = null; resolve('pending'); } }, ms);
      });
    },
  };

  // A short note in the corner, for what happened after the pick ("Copied …").
  globalThis.__trexPickNote = text => {
    const note = document.createElement('div');
    note.style.cssText = 'position:fixed;right:8px;bottom:8px;z-index:2147483647;pointer-events:none;' + tag;
    note.textContent = text + (slow ? ' (without the source: finding it took over 2 s)' : '');
    document.documentElement.appendChild(note);
    setTimeout(() => note.remove(), 1500);
    return 'ok';
  };

  return 'started';
})()
