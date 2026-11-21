// Element Handoff's pick mode, injected into a Browser Pane's page with
// `kb ctl -i ID eval` (pick.lua). One expression: it turns pick mode on, or off
// if it is already on, and returns "started" or "cancelled".
//
// While on, the element under the pointer is outlined the way kb's own Inspect
// does it (margin, border, padding, content and a label), in a layer that
// ignores the mouse. Capture listeners on window take the press and click that
// pick, so the page never sees them; the wheel still scrolls. Esc cancels.
//
// pick-wait.sh then calls globalThis.__trexPick.wait(ms) in a loop. It resolves
// to "picked\n" + the description, "cancelled", or "pending" when `ms` passes
// first (kb gives up on a request after 30 s, so each wait is shorter). If no
// wait comes for LEASE ms, the waiter is gone and pick mode ends by itself.
(() => {
  const LEASE = 90000;
  const HTML_MAX = 300;
  const ROOT_ID = '__trex_pick';

  const previous = globalThis.__trexPick;
  if (previous && previous.active()) { previous.cancel(); return 'cancelled'; }

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

  // --- the outline -----------------------------------------------------------

  const root = document.createElement('div');
  root.id = ROOT_ID;
  root.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:2147483647';
  for (let i = 0; i < 6; i++) root.appendChild(document.createElement('div'));
  const [margin, border, padding, content, label, hint] = root.children;
  const tag = 'background:#202124;color:#e8eaed;font:12px/20px ui-monospace,Menlo,monospace;padding:0 6px;' +
    'border-radius:3px;white-space:nowrap;max-width:90vw;overflow:hidden;text-overflow:ellipsis';
  hint.style.cssText = 'position:fixed;right:8px;bottom:8px;' + tag;
  hint.textContent = 'Pick an element for the agent · Esc cancels';
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

  const describe = el => {
    const attrs = [];
    if (el.id) attrs.push('id="' + el.id + '"');
    const classes = [...el.classList].slice(0, 3);
    if (classes.length) attrs.push('class="' + classes.join(' ') + '"');
    const first = '<' + el.localName + attrs.map(a => ' ' + a).join('') + '>';

    const r = el.getBoundingClientRect(), n = Math.round;
    const shell = el.cloneNode(false).outerHTML;
    const close = '</' + el.localName + '>';
    let html = shell;
    if (shell.endsWith(close)) {
      const text = (el.innerText ?? el.textContent ?? '').replace(/\s+/g, ' ').trim();
      html = shell.slice(0, -close.length) + text + close;
    }
    if (html.length > HTML_MAX) html = html.slice(0, HTML_MAX - 1) + '…';

    return [
      first,
      'page: ' + location.href,
      'path: ' + selector(el),
      'box: ' + n(r.width) + '×' + n(r.height) + ' at ' + n(r.left + scrollX) + ',' + n(r.top + scrollY) + ' (page px)',
      'html: ' + html,
    ].join('\n');
  };

  // --- listeners ---------------------------------------------------------------

  let result = null;        // "picked\n…" or "cancelled" once pick mode ends
  let wake = null;          // resolves the pending wait()
  let lease = null;
  let swallowUntil = 0;     // after a pick, the rest of that click is swallowed too
  let frame = 0, lastX = 0, lastY = 0;

  const stop = e => { e.preventDefault(); e.stopImmediatePropagation(); };

  const finish = value => {
    if (result !== null) return;
    result = value;
    root.remove();
    clearTimeout(lease);
    for (const [type, fn] of pointing) removeEventListener(type, fn, true);
    // The press that picked is followed by its release and click, and a
    // double click by a second press: keep swallowing those, then let go.
    setTimeout(() => { for (const [type, fn] of clicking) removeEventListener(type, fn, true); }, 1000);
    if (wake) { wake(value); wake = null; }
  };

  const onMove = e => {
    lastX = e.clientX; lastY = e.clientY;
    if (frame) return;
    frame = requestAnimationFrame(() => {
      frame = 0;
      const el = at(lastX, lastY);
      if (el && !root.contains(el)) outline(el);
    });
  };

  const onPress = e => {
    if (result !== null) { if (performance.now() < swallowUntil) stop(e); return; }
    stop(e);
    if (e.button !== 0) return;
    const el = at(e.clientX, e.clientY) || shown;
    if (!el) return;
    outline(el);
    swallowUntil = performance.now() + 1000;
    finish('picked\n' + describe(el));
  };

  const onRest = e => {
    if (result === null || performance.now() < swallowUntil) stop(e);
  };

  const onKey = e => {
    if (e.key !== 'Escape') return;
    stop(e);
    finish('cancelled');
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
    wait: ms => {
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
    note.textContent = text;
    document.documentElement.appendChild(note);
    setTimeout(() => note.remove(), 1500);
    return 'ok';
  };

  return 'started';
})()
