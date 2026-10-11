import test from 'node:test';
import assert from 'node:assert/strict';
import { html } from '../js/dom.js';

test('插值会转义 HTML', () => {
  assert.equal(String(html`<p>${'<img src=x onerror=alert(1)>'}</p>`), '<p>&lt;img src=x onerror=alert(1)&gt;</p>');
});

test('引号也转义，放在属性里安全', () => {
  assert.equal(String(html`<a title="${'" onclick="x'}">`), '<a title="&quot; onclick=&quot;x">');
});

test('嵌套 html 和数组不会被二次转义', () => {
  const items = ['a', '<b>'].map(x => html`<li>${x}</li>`);
  assert.equal(String(html`<ul>${items}</ul>`), '<ul><li>a</li><li>&lt;b&gt;</li></ul>');
});

test('null、undefined、false 不输出，0 照常输出', () => {
  assert.equal(String(html`${null}${undefined}${false}${0}`), '0');
});
