const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

export const esc = text => String(text).replace(/[&<>"']/g, c => ESCAPES[c]);

/** 已经是 HTML 的字符串，拼接时不再转义 */
export class Raw {
  constructor(text) { this.text = text; }
  toString() { return this.text; }
}

export const raw = text => new Raw(text);

/** html`<p>${x}</p>`：插值自动转义，嵌套的 html`` 和数组原样拼接 */
export function html(strings, ...values) {
  return raw(strings.reduce((out, s, i) => out + s + (i < values.length ? show(values[i]) : ''), ''));
}

function show(value) {
  if (value instanceof Raw) return value.text;
  if (Array.isArray(value)) return value.map(show).join('');
  if (value === null || value === undefined || value === false) return '';
  return esc(value);
}
