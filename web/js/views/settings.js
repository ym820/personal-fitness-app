import { html } from '../dom.js';
import * as F from '../format.js';

export function settingsView(app) {
  const { store } = app;
  const settings = store.loadSettings();
  const status = store.loadSyncStatus();

  return {
    html: html`
      <nav class="navbar"><a class="back" href="#/history">‹ 记录</a></nav>
      <h1 class="large-title">设置</h1>
      <h3 class="section-header" style="margin-top:0">GitHub 同步</h3>
      <form data-form>
        <ul class="group">
          <li><label class="field"><span>仓库</span>
            <input name="repo" value="${settings.repo}" placeholder="用户名/仓库名" autocapitalize="off" autocorrect="off" spellcheck="false">
          </label></li>
          <li><label class="field"><span>令牌</span>
            <input name="token" type="password" autocomplete="off" placeholder="${settings.token ? `已保存，末尾 ${settings.token.slice(-4)}` : 'github_pat_…'}">
          </label></li>
        </ul>
        <p class="section-footer">令牌只存在这台手机上。只需要这个仓库的 Contents 读写权限。令牌留空保存会保留原来的令牌。</p>
        <div class="stack"><button class="button primary" type="submit">保存并同步</button></div>
      </form>
      <h3 class="section-header">状态</h3>
      <ul class="group"><li class="pair"><span>同步</span><span class="secondary">${statusText(settings, status, app.syncing)}</span></li></ul>
      ${status.error ? html`<p class="section-footer error">${status.error}</p>` : ''}
      ${settings.token
        ? html`<div class="stack">
            <button class="button" data-action="sync">立即同步</button>
            <button class="button destructive" data-action="clear">清除令牌</button>
          </div>`
        : ''}`,
    mount(root) {
      root.querySelector('[data-form]').addEventListener('submit', event => {
        event.preventDefault();
        const form = new FormData(event.target);
        const token = String(form.get('token')).trim() || store.loadSettings().token;
        store.saveSettings({ repo: String(form.get('repo')).trim(), token });
        store.saveSyncStatus({ lastSuccessAt: null, error: null });
        app.sync();
        app.refresh();
      });
      root.querySelector('[data-action=sync]')?.addEventListener('click', () => {
        app.sync();
        app.refresh();
      });
      root.querySelector('[data-action=clear]')?.addEventListener('click', () => {
        if (!confirm('清除令牌？训练记录还会留在这台手机上。')) return;
        store.saveSettings({ ...store.loadSettings(), token: '' });
        store.saveSyncStatus({ lastSuccessAt: null, error: null });
        app.refresh();
      });
    },
  };
}

function statusText(settings, status, syncing) {
  if (!settings.token) return '未开启同步';
  if (syncing) return '正在同步…';
  return status.lastSuccessAt ? `上次成功：${F.dateTime(status.lastSuccessAt)}` : '还没有同步成功过';
}
