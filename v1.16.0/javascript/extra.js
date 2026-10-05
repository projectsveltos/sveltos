/*
 * Strip leading '$' or '$ ' from code snippets on copy.
 */
(function () {
  'use strict';

  function strip(text) {
    return typeof text === 'string' ? text.replace(/^(\$\s*)/gm, '') : text;
  }

  // Layer 1: prototype patch: Intercepts calls that go through the prototype
  // chain regardless of when they are made relative to this script loading.
  if (typeof Clipboard !== 'undefined' && Clipboard.prototype.writeText) {
    const _proto = Clipboard.prototype.writeText;
    Clipboard.prototype.writeText = function (text) {
      try {
        return _proto.call(this, strip(text));
      } catch {
        return _proto.call(this, text);
      }
    };
  }

  // Layer 2: instance patch: Shadows the prototype on the live object so
  // a direct navigator.clipboard.writeText(…) lookup finds our version first.
  if (navigator.clipboard) {
    const _orig = navigator.clipboard.writeText.bind(navigator.clipboard);
    navigator.clipboard.writeText = function (text) {
      try {
        return _orig(strip(text));
      } catch {
        return _orig(text);
      }
    };
  }

  // Layer 3: copy DOM event: Handles execCommand-based copies and Ctrl+C.
  document.addEventListener('copy', function (e) {
    try {
      if (!e.clipboardData) return;
      const sel = window.getSelection() ? window.getSelection().toString() : '';
      if (!sel) return;
      const stripped = strip(sel);
      if (stripped !== sel) {
        e.clipboardData.setData('text/plain', stripped);
        e.preventDefault();
      }
    } catch {
    }
  });

}());