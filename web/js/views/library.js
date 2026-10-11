import { html } from '../dom.js';
import { BODY_PARTS, filterExercises, thumbnailURL, watchURL } from '../catalog.js';
import * as F from '../format.js';
import { art, thumb } from './common.js';

export function libraryView(app) {
  const { catalog } = app;
  return {
    html: html`
      <h1 class="large-title">动作库</h1>
      <input class="search" type="search" placeholder="中文或英文名、器材" data-search>
      <div data-results>${groups(catalog.exercises)}</div>
      <p class="section-footer">动作插图来自 <a href="https://github.com/bryllim/workout-guide" target="_blank" rel="noopener">Workout Guide</a>，作者 Bryl Lim，基于 Everkinetic 的作品，按 <a href="https://creativecommons.org/licenses/by-sa/4.0/" target="_blank" rel="noopener">CC BY-SA 4.0</a> 协议使用。</p>`,
    mount(root) {
      const results = root.querySelector('[data-results]');
      root.querySelector('[data-search]').addEventListener('input', event => {
        const query = event.target.value;
        const list = filterExercises(catalog.exercises, query);
        results.innerHTML = String(list.length ? html`${groups(list)}` : html`<p class="empty">没有找到「${query.trim()}」</p>`);
      });
    },
  };
}

function groups(list) {
  return BODY_PARTS.map(([part, name]) => {
    const items = list.filter(e => e.bodyPart === part);
    return items.length ? html`<h3 class="section-header">${name}</h3><ul class="list">${items.map(row)}</ul>` : '';
  });
}

function row(exercise) {
  return html`<li><a class="row" href="#/exercise/${exercise.id}">
    ${thumb(exercise)}
    <div class="row-text">
      <strong>${exercise.nameZh}</strong>
      <span class="secondary">${exercise.nameEn}</span>
      <span class="footnote secondary">${exercise.equipmentZh}</span>
    </div>
  </a></li>`;
}

export function exerciseView(app, id) {
  const exercise = app.catalog.exercise(id);
  if (!exercise) return { html: html`<p class="empty">找不到这个动作</p>` };
  const videos = app.catalog.videosFor(id);

  return {
    html: html`
      <nav class="navbar"><button class="back" data-action="back">‹ 返回</button><span>${exercise.nameZh}</span></nav>
      <div class="demo" data-demo role="img" aria-label="${exercise.nameZh}示范图">
        ${exercise.images.map((name, i) => html`${i > 0 ? html`<span class="demo-arrow" aria-hidden="true">→</span>` : ''}${art(name)}`)}
      </div>
      <h1 class="title">${exercise.nameZh}</h1>
      <p class="subtitle secondary">${exercise.nameEn}</p>
      ${videos.length ? html`<h3 class="section-header">示范视频</h3><div class="videos">${videos.map(videoCard)}</div>` : ''}
      <dl class="info">
        <dt>器材</dt><dd>${exercise.equipmentZh}<span class="footnote secondary">${exercise.equipmentEn}</span></dd>
        <dt>主要练到</dt><dd>${exercise.primaryMuscles.map(F.muscleZh).join('、')}</dd>
        <dt>计数</dt><dd>${exercise.unit === 'reps' ? '按次数' : '按秒数'}</dd>
      </dl>
      <h3 class="section-header">动作要点</h3>
      <ol class="tips">${exercise.tipsZh.map(tip => html`<li>${tip}</li>`)}</ol>`,
    mount(root) {
      root.querySelector('[data-action=back]').addEventListener('click', () => {
        if (history.length > 1) history.back();
        else app.navigate('#/library');
      });
      // 横向的图（比如腿举）上下排，竖向的图（比如深蹲）左右排，让图尽量大
      const demo = root.querySelector('[data-demo]');
      const first = demo.querySelector('img');
      const layout = () => demo.classList.toggle('wide', first.naturalWidth / first.naturalHeight > 1.2);
      if (first.complete) layout();
      else first.addEventListener('load', layout);
    },
  };
}

/** B 站封面图有防盗链，不带来源（referrer）才能加载 */
function videoCard(video) {
  const cover = thumbnailURL(video);
  return html`<a class="video" href="${watchURL(video)}" target="_blank" rel="noopener">
    <span class="video-thumb">
      ${cover ? html`<img src="${cover}" alt="" loading="lazy" referrerpolicy="no-referrer">` : ''}
      <span class="badge ${video.platform}">${video.platform === 'youtube' ? 'YouTube' : 'bilibili'}</span>
      ${video.durationSeconds ? html`<span class="video-duration">${F.duration(video.durationSeconds)}</span>` : ''}
    </span>
    <span class="video-title">${video.title}</span>
    <span class="footnote secondary">${video.author}</span>
  </a>`;
}
