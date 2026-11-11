// iOS の WKWebView には Web MIDI が無いので、CoreMIDI ブリッジ経由で navigator.requestMIDIAccess を提供する
(function () {
  if (navigator.requestMIDIAccess) return;
  const h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midi;
  if (!h) return;
  const ins = new Map(), outs = new Map();
  let resolver = null;
  class Port {
    constructor(type, id, name) { this.type = type; this.id = id; this.name = name; this.manufacturer = ''; this.state = 'connected'; this.connection = 'open'; this.onmidimessage = null; }
    send(data, ts) {
      const delay = ts ? Math.max(0, ts - performance.now()) : 0;
      h.postMessage({ a: 'send', id: this.id, d: Array.from(data), delay: delay });
    }
  }
  const access = { inputs: ins, outputs: outs, onstatechange: null, sysexEnabled: true };
  function sync(map, list, type) {
    const seen = new Set();
    for (const x of list) { seen.add(x.id); if (!map.has(x.id)) map.set(x.id, new Port(type, x.id, x.name)); }
    for (const k of [...map.keys()]) if (!seen.has(k)) map.delete(k);
  }
  window.__vaMidiPorts = function (p) {
    sync(ins, p.inputs || [], 'input'); sync(outs, p.outputs || [], 'output');
    if (access.onstatechange) { try { access.onstatechange({}); } catch (e) {} }
    if (resolver) { resolver(access); resolver = null; }
  };
  window.__vaMidiIn = function (id, msgs) {
    const p = ins.get(String(id)); if (!p || !p.onmidimessage) return;
    const now = performance.now();
    for (const m of msgs) { try { p.onmidimessage({ data: new Uint8Array(m), timeStamp: now, target: p }); } catch (e) {} }
  };
  navigator.requestMIDIAccess = function () {
    return new Promise(function (resolve) {
      resolver = resolve; h.postMessage({ a: 'list' });
      setTimeout(function () { if (resolver) { resolver(access); resolver = null; } }, 1500);
    });
  };
})();
