/**
 * 进行中训练的暂停。暂停时记下开始暂停的时间，继续时把暂停了多久加到 pausedSeconds，
 * 休息倒计时往后挪同样的时间。已练时长和存下的训练时长都不算暂停的时间。
 */

/** 已练了多少秒，不含暂停 */
export function elapsedSeconds(session, now = Date.now()) {
  const end = session.pausedAt ?? now;
  return Math.max(0, (end - Date.parse(session.startedAt)) / 1000 - (session.pausedSeconds ?? 0));
}

export const isPaused = session => session.pausedAt != null;

export function pauseSession(session, now = Date.now()) {
  return isPaused(session) ? session : { ...session, pausedAt: now };
}

export function resumeSession(session, now = Date.now()) {
  if (!isPaused(session)) return session;
  const paused = Math.max(0, now - session.pausedAt);
  return {
    ...session,
    pausedAt: null,
    pausedSeconds: (session.pausedSeconds ?? 0) + paused / 1000,
    restEndsAt: session.restEndsAt == null ? session.restEndsAt : session.restEndsAt + paused,
  };
}
