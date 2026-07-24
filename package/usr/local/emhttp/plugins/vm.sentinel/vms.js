/* VM Sentinel — WebGUI helper JS (spec §13). No external dependencies.
 * SPDX-License-Identifier: MIT
 * Posts are CSRF-protected: csrf_token is injected by each page from Unraid.
 */
(function (w) {
  'use strict';
  function post(data) {
    var body = new URLSearchParams();
    body.append('csrf_token', w.VMS_CSRF || '');
    Object.keys(data).forEach(function (k) { body.append(k, data[k]); });
    return fetch('/plugins/vm.sentinel/include/save.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
      credentials: 'same-origin'
    }).then(function (r) {
      // Never throw on non-JSON: surface the raw text so failures are visible.
      return r.text().then(function (t) {
        try { return JSON.parse(t); }
        catch (e) { return { ok: false, error: (t ? t.slice(0, 140) : ('HTTP ' + r.status)) }; }
      });
    }).catch(function (e) { return { ok: false, error: 'Request failed: ' + e.message }; });
  }

  function flash(el, ok, msg) {
    if (!el) return;
    el.textContent = msg || (ok ? 'Saved.' : 'Something went wrong.');
    el.className = 'vms-flash ' + (ok ? 'vms-ok' : 'vms-err');
    el.style.display = 'inline-block';
    setTimeout(function () { el.style.display = 'none'; }, 4000);
  }

  w.VMS = {
    post: post,
    flash: flash,
    saveForm: function (form, statusEl) {
      var data = {};
      Array.prototype.forEach.call(form.elements, function (e) {
        if (!e.name) return;
        if (e.type === 'checkbox') data[e.name] = e.checked ? '1' : '0';
        else data[e.name] = e.value;
      });
      return post(data).then(function (res) {
        flash(statusEl, res.ok, res.error || (res.ok ? 'Saved.' : 'Save failed.'));
        return res;
      });
    },
    testNotify: function (target, statusEl) {
      flash(statusEl, true, 'Sending test…');
      return post({ action: 'test_notify', target: target }).then(function (res) {
        var r = (res.result && res.result.results) || [];
        var parts = r.map(function (x) { return x.provider + ': ' + (x.ok ? 'ok' : ('failed' + (x.code ? ' (' + x.code + ')' : ''))); });
        flash(statusEl, r.every(function (x) { return x.ok; }), parts.join('  •  ') || 'No providers enabled.');
        return res;
      });
    }
  };
}(window));
