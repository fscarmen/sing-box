"""In-memory realtime view: active connections, per-batch rate samples and a push hub."""
import json
import queue
import threading
import time
from collections import deque


def _now_ms():
    return int(time.time() * 1000)


class Live:
    def __init__(self, history_seconds=900, top=60):
        self.lock = threading.Lock()
        self.active = {}
        self.samples = deque(maxlen=max(60, int(history_seconds)))
        self.top = top
        self.last_batch = None
        self.skip_next = True

    def reset(self):
        with self.lock:
            self.active.clear()
            # The first batch after a (re)subscribe replays totals; it is not a rate.
            self.skip_next = True

    def upsert(self, cid, info):
        with self.lock:
            current = self.active.get(cid)
            if current is None:
                current = {'id': cid, 'up': 0, 'down': 0, 'ru': 0.0, 'rd': 0.0, 'updated': _now_ms()}
                self.active[cid] = current
            current.update(info)

    def close(self, cid):
        with self.lock:
            self.active.pop(cid, None)

    def apply(self, deltas, now_ms=None):
        """deltas: list of (cid, ip, inbound, outbound, du, dd) from one telemetry batch."""
        now_ms = now_ms or _now_ms()
        with self.lock:
            previous = self.last_batch
            self.last_batch = now_ms
            skip = self.skip_next
            self.skip_next = False
            for cid, _ip, _inbound, _outbound, du, dd in deltas:
                conn = self.active.get(cid)
                if conn is not None:
                    elapsed = max(0.25, (now_ms - conn.get('updated', now_ms)) / 1000) if conn.get('updated') else 1.0
                    conn['ru'], conn['rd'] = du / elapsed, dd / elapsed
                    conn['updated'] = now_ms
            if skip or previous is None:
                return
            seconds = max(0.25, min(10.0, (now_ms - previous) / 1000))
            up = down = 0
            by_out, by_in = {}, {}
            for _cid, _ip, inbound, outbound, du, dd in deltas:
                up += du
                down += dd
                o = by_out.setdefault(outbound or '?', [0, 0])
                o[0] += du
                o[1] += dd
                i = by_in.setdefault(inbound or '?', [0, 0])
                i[0] += du
                i[1] += dd
            scale = 1 / seconds
            self.samples.append({
                't': now_ms, 'up': up * scale, 'down': down * scale,
                'out': {k: [v[0] * scale, v[1] * scale] for k, v in by_out.items()},
                'in': {k: [v[0] * scale, v[1] * scale] for k, v in by_in.items()},
            })

    def frame(self):
        now = _now_ms()
        with self.lock:
            stale = not self.samples or now - self.samples[-1]['t'] > 3500
            last = None if stale else self.samples[-1]
            ips = {}
            rows = []
            for conn in self.active.values():
                fresh = now - conn.get('updated', 0) < 3500
                ru, rd = (conn['ru'], conn['rd']) if fresh else (0.0, 0.0)
                entry = ips.setdefault(conn.get('ip', '?'), {'online': 0, 'ru': 0.0, 'rd': 0.0})
                entry['online'] += 1
                entry['ru'] += ru
                entry['rd'] += rd
                rows.append((ru + rd, conn, ru, rd))
            rows.sort(key=lambda r: (r[0], r[1].get('started', 0)), reverse=True)
            top = [self._public(conn, ru, rd) for _score, conn, ru, rd in rows[:self.top]]
            return {
                't': now,
                'up': last['up'] if last else 0, 'down': last['down'] if last else 0,
                'out': last['out'] if last else {}, 'in': last['in'] if last else {},
                'active': len(self.active), 'online_ips': len(ips), 'ips': ips, 'top': top,
            }

    def series(self, seconds=300):
        cutoff = _now_ms() - seconds * 1000
        with self.lock:
            return [s for s in self.samples if s['t'] >= cutoff]

    def connections(self):
        now = _now_ms()
        with self.lock:
            out = []
            for conn in self.active.values():
                fresh = now - conn.get('updated', 0) < 3500
                out.append(self._public(conn, conn['ru'] if fresh else 0.0, conn['rd'] if fresh else 0.0))
            return out

    def ids_for(self, predicate):
        with self.lock:
            return [cid for cid, conn in self.active.items() if predicate(conn.get('ip', ''))]

    @staticmethod
    def _public(conn, ru, rd):
        return {k: conn.get(k) for k in ('id', 'ip', 'domain', 'destination', 'protocol', 'inbound', 'outbound', 'rule',
                                         'chain', 'started', 'up', 'down')} | {'ru': round(ru), 'rd': round(rd)}


class Hub:
    """Fan-out of JSON frames to server-sent-event subscribers."""

    def __init__(self, limit=8):
        self.limit = limit
        self.lock = threading.Lock()
        self.subscribers = set()

    def subscribe(self):
        with self.lock:
            if len(self.subscribers) >= self.limit:
                return None
            q = queue.Queue(maxsize=4)
            self.subscribers.add(q)
            return q

    def unsubscribe(self, q):
        with self.lock:
            self.subscribers.discard(q)

    def publish(self, frame):
        data = json.dumps(frame, separators=(',', ':'))
        with self.lock:
            targets = list(self.subscribers)
        for q in targets:
            try:
                q.put_nowait(data)
            except queue.Full:
                try:
                    q.get_nowait()
                    q.put_nowait(data)
                except (queue.Empty, queue.Full):
                    pass

    def count(self):
        with self.lock:
            return len(self.subscribers)
