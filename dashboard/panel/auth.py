"""Password login, hashed session tokens, CSRF and rate limiting."""
import hashlib
import hmac
import secrets
import time

FAILURE_WINDOW = 900
PER_IP_LIMIT, GLOBAL_LIMIT = 10, 100


def token_hash(token):
    return hashlib.sha256(token.encode()).hexdigest()


class Auth:
    def __init__(self, settings, store):
        self.settings = settings
        self.store = store

    def accounts(self):
        """Primary account plus optional `users` entries ({username, salt, password_hash}) from the secrets file."""
        s = self.settings.secrets
        found = [{'username': s['username'], 'salt': s['salt'], 'password_hash': s['password_hash']}]
        for extra in s.get('users', []):
            if extra.get('username') and extra.get('salt') and extra.get('password_hash'):
                found.append(extra)
        return found

    def check_password(self, username, password):
        """Returns the matched account name or ''. Always derives one hash so timing does not reveal names."""
        accounts = self.accounts()
        account = next((a for a in accounts if hmac.compare_digest(username.encode(), a['username'].encode())), None)
        target = account or accounts[0]
        digest = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(target['salt']), 600000).hex()
        if account and hmac.compare_digest(digest, account['password_hash']):
            return account['username']
        return ''

    def throttled(self, ip):
        now = int(time.time())
        with self.store.write() as c:
            c.execute('DELETE FROM failures WHERE at<?', (now - FAILURE_WINDOW,))
            c.execute('DELETE FROM sessions WHERE expires<?', (now,))
            count = c.execute('SELECT COUNT(*) FROM failures WHERE ip=?', (ip,)).fetchone()[0]
            total = c.execute('SELECT COUNT(*) FROM failures').fetchone()[0]
        return count >= PER_IP_LIMIT or total >= GLOBAL_LIMIT

    def fail(self, ip):
        with self.store.write() as c:
            c.execute('INSERT INTO failures VALUES(?,?)', (ip, int(time.time())))

    def create(self, ip, agent, remember, user=''):
        token = secrets.token_urlsafe(48)
        csrf = secrets.token_urlsafe(32)
        days = int(self.settings.get('site.session_days_remember' if remember else 'site.session_days_default'))
        now = int(time.time())
        with self.store.write() as c:
            c.execute('INSERT INTO sessions(token_hash,csrf,expires,created,ip,agent,last_seen,user) VALUES(?,?,?,?,?,?,?,?)',
                      (token_hash(token), csrf, now + days * 86400, now, ip, (agent or '')[:160], now, user[:64]))
            c.execute('INSERT INTO audit VALUES(?,?,?,?)', (now, 'login', ip, user[:64]))
        return token, days

    def lookup(self, token):
        if not token:
            return None
        now = int(time.time())
        row = self.store.reader().execute('SELECT token_hash,csrf,expires,last_seen,user FROM sessions WHERE token_hash=? AND expires>?',
                                          (token_hash(token), now)).fetchone()
        if row and now - (row['last_seen'] or 0) > 60:
            with self.store.write() as c:
                c.execute('UPDATE sessions SET last_seen=? WHERE token_hash=?', (now, row['token_hash']))
        return row

    def revoke(self, token=None, session_id=None, keep=None):
        with self.store.write() as c:
            if token:
                c.execute('DELETE FROM sessions WHERE token_hash=?', (token_hash(token),))
            elif session_id == '*':
                c.execute('DELETE FROM sessions WHERE token_hash!=?', (keep or '',))
            elif session_id:
                # Public ids are hash prefixes; never expose full hashes.
                c.execute("DELETE FROM sessions WHERE substr(token_hash,1,16)=? AND token_hash!=?", (session_id, keep or ''))

    def sessions(self, current_hash):
        rows = self.store.reader().execute('SELECT token_hash,expires,created,ip,agent,last_seen,user FROM sessions WHERE expires>? ORDER BY last_seen DESC',
                                           (int(time.time()),)).fetchall()
        return [{'id': r['token_hash'][:16], 'current': r['token_hash'] == current_hash, 'expires': r['expires'],
                 'created': r['created'], 'ip': r['ip'], 'agent': r['agent'], 'last_seen': r['last_seen'], 'user': r['user'] or ''} for r in rows]
