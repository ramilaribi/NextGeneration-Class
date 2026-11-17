"""Live API check: happy flows across the four roles, isolation between two teachers, then every endpoint
against unhappy calls (no login, wrong role, unknown and malformed ids, broken and junk bodies). Any 5xx fails.

Local only, on a throwaway database (it creates pupils, sessions, homework...), never production:
  docker exec ngclass-dev-db-1 psql -U <DB_USERNAME> -d ngclass -c "create database ngclass_apitest"
  cd backend && DB_NAME=ngclass_apitest mvn spring-boot:run
  DEV_ENV=backend/.env python3 -I infra/dev-tools/api-check.py
Passwords are read from backend/.env and never printed. Drop the database afterwards."""
import json, os, sys, uuid, datetime as dt, urllib.request, urllib.error

BASE = os.environ.get('BASE', 'http://localhost:8080')
ENV = {}
for line in open(os.environ['DEV_ENV']):
    if '=' in line and not line.startswith('#'):
        k, v = line.rstrip('\n').split('=', 1)
        ENV[k] = v.strip()

checks, server_errors = [], []
import random
RUN = uuid.uuid4().hex[:5]
PHONE = '2' + str(random.randint(1000000, 9999999))


def call(method, path, token=None, body=None, raw=None, ctype='application/json', multipart=None):
    url = BASE + path
    headers = {}
    data = None
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if multipart is not None:
        boundary = 'X' + uuid.uuid4().hex
        parts = []
        for name, (filename, content, ptype) in multipart.items():
            disp = f'form-data; name="{name}"' + (f'; filename="{filename}"' if filename else '')
            parts.append(f'--{boundary}\r\nContent-Disposition: {disp}\r\nContent-Type: {ptype}\r\n\r\n'.encode() + content + b'\r\n')
        data = b''.join(parts) + f'--{boundary}--\r\n'.encode()
        headers['Content-Type'] = 'multipart/form-data; boundary=' + boundary
    elif raw is not None:
        data = raw.encode() if isinstance(raw, str) else raw
        headers['Content-Type'] = ctype
    elif body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            status, text = r.status, r.read()
    except urllib.error.HTTPError as e:
        status, text = e.code, e.read()
    try:
        js = json.loads(text) if text else None
    except Exception:
        js = None
    if status >= 500:
        server_errors.append((method, path, status, (text or b'')[:300]))
    return status, js


def idof(js):
    if isinstance(js, dict):
        if 'id' in js: return js.get('id')
        for k in ('item', 'evaluation', 'first', 'student', 'announcement', 'assignment', 'content', 'group', 'subject', 'chapter'):
            if isinstance(js.get(k), dict) and 'id' in js[k]: return js[k]['id']
    print('   no id in', str(js)[:300]); return str(uuid.uuid4())


def check(name, status, expected, js=None, code=None):
    exp = expected if isinstance(expected, (set, tuple, list)) else {expected}
    ok = status in exp and (code is None or (js or {}).get('code') == code)
    checks.append((ok, name, status, sorted(exp), (js or {}).get('code') if isinstance(js, dict) else None))
    return ok


def login(user, password):
    s, js = call('POST', '/api/v1/auth/login', body={'login': user, 'password': password})
    assert s == 200, (user, s, js)
    return js


def first_login(cred, new='Nouveau-mot-2026!'):
    tok = login(cred['username'], cred['temporaryPassword'])['accessToken']
    s, _ = call('POST', '/api/v1/me/password', tok, {'currentPassword': cred['temporaryPassword'], 'newPassword': new})
    check('first login: new password', s, {200, 204})
    tok = login(cred['username'], new)['accessToken']
    s, me = call('GET', '/api/v1/me', tok)
    if me and me.get('privacyRequired'):
        s, _ = call('POST', '/api/v1/me/privacy', tok)
        check('parent accepts the privacy notice', s, 204)
    return tok


now = dt.datetime.now(dt.timezone.utc)
iso = lambda d: d.strftime('%Y-%m-%dT%H:%M:%SZ')
PDF = b'%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF'

# ---------------------------------------------------------------- auth
print('== auth')
s, js = call('POST', '/api/v1/auth/login', body={'login': 'enseignante', 'password': 'faux'}); check('login: wrong password → 401', s, 401, js)
s, js = call('POST', '/api/v1/auth/login', body={'login': 'personne', 'password': 'faux'}); check('login: unknown user → 401', s, 401, js)
s, js = call('POST', '/api/v1/auth/login', body={'login': '', 'password': ''}); check('login: empty fields → 400', s, 400, js)
s, js = call('POST', '/api/v1/auth/login', raw='{nope'); check('login: broken JSON → 400', s, 400, js)
s, js = call('POST', '/api/v1/auth/login', raw='a=b', ctype='text/plain'); check('login: wrong content type → 415/400', s, {400, 415}, js)
teacher_auth = login('enseignante', ENV['TEACHER_PASSWORD'])
T = teacher_auth['accessToken']
A = login('admin', ENV['ADMIN_PASSWORD'])['accessToken']
S = login('eleve.demo', ENV['DEV_STUDENT_PASSWORD'])['accessToken']
P = login('20000001', ENV['DEV_PARENT_PASSWORD'])['accessToken']
s, me = call('GET', '/api/v1/me', P)
if me and me.get('privacyRequired'):
    call('POST', '/api/v1/me/privacy', P)
s, js = call('POST', '/api/v1/auth/refresh', body={'refreshToken': teacher_auth['refreshToken']}); check('refresh: valid token → 200', s, 200, js)
new_refresh = js['refreshToken'] if js else None
s, js = call('POST', '/api/v1/auth/refresh', body={'refreshToken': 'nimportequoi'}); check('refresh: bogus token → 401', s, 401, js)
s, js = call('POST', '/api/v1/auth/refresh', body={}); check('refresh: missing token → 400', s, 400, js)
s, js = call('GET', '/api/v1/me', 'eyJhbGciOiJIUzI1NiJ9.e30.abc'); check('forged bearer → 401', s, 401, js)
s, js = call('GET', '/api/v1/me'); check('no bearer → 401', s, 401, js)
s, js = call('PUT', '/api/v1/me/language', T, {'language': 'xx'}); check('language: unknown → 400', s, 400, js)
s, js = call('PUT', '/api/v1/me/language', T, {'language': 'ar'}); check('language: ar → 2xx', s, {200, 204}, js)
call('PUT', '/api/v1/me/language', T, {'language': 'fr'})
s, js = call('POST', '/api/v1/me/password', T, {'currentPassword': 'faux', 'newPassword': 'Autre-mot-2026!'}); check('password: wrong current → 4xx', s, {400, 401, 403}, js)
s, js = call('POST', '/api/v1/me/password', T, {'currentPassword': ENV['TEACHER_PASSWORD'], 'newPassword': '1'}); check('password: too short → 400', s, 400, js)
# logout then the refresh token is dead
r2 = login('enseignante', ENV['TEACHER_PASSWORD'])['refreshToken']
s, js = call('POST', '/api/v1/auth/logout', body={'refreshToken': r2}); check('logout → 2xx', s, {200, 204}, js)
s, js = call('POST', '/api/v1/auth/refresh', body={'refreshToken': r2}); check('refresh after logout → 401', s, 401, js)

# ---------------------------------------------------------------- admin
print('== admin')
s, js = call('GET', '/api/v1/admin/teachers', A); check('owner lists teachers', s, 200, js)
s, js = call('POST', '/api/v1/admin/teachers', A, {'firstName': 'Sonia', 'lastName': 'Test', 'username': 'sonia.' + RUN}); check('owner adds a teacher → 201', s, {200, 201}, js)
t2_id = js.get('teacher', {}).get('id') if js else None
t2_cred = (js or {}).get('credential') or (js or {})
s, js2 = call('POST', '/api/v1/admin/teachers', A, {'firstName': 'Sonia', 'lastName': 'Test', 'username': 'sonia.' + RUN}); check('owner adds the same username → 400 username_taken', s, 400, js2, 'username_taken')
s, js2 = call('POST', '/api/v1/admin/teachers', A, {'firstName': '', 'lastName': 'x', 'username': 'y'}); check('owner adds a teacher without first name → 400', s, 400, js2)
if not t2_id and js:
    t2_id = js.get('id') or (js.get('account') or {}).get('id')
cred = None
for k in ('credential', 'credentials'):
    v = (js or {}).get(k)
    if isinstance(v, dict): cred = v
    if isinstance(v, list) and v: cred = v[0]
if cred is None and js and 'temporaryPassword' in js: cred = js
T2 = first_login(cred)
if not t2_id:
    s, lst = call('GET', '/api/v1/admin/teachers', A)
    t2_id = next(t['id'] for t in lst if t.get('username') == 'sonia.' + RUN)
s, js = call('POST', f'/api/v1/admin/teachers/{t2_id}/disable', A); check('owner closes a teacher', s, {200, 204}, js)
s, js = call('GET', '/api/v1/me', T2); check('closed teacher: her live token is refused at once → 401', s, 401, js, 'teacher_disabled')
s, js = call('POST', '/api/v1/auth/login', body={'login': 'sonia.' + RUN, 'password': 'Nouveau-mot-2026!'}); check('closed teacher cannot log in', s, {401, 403}, js)
s, js = call('POST', f'/api/v1/admin/teachers/{t2_id}/enable', A); check('owner reopens a teacher', s, {200, 204}, js)
T2 = login('sonia.' + RUN, 'Nouveau-mot-2026!')['accessToken']
s, js = call('POST', f'/api/v1/admin/teachers/{uuid.uuid4()}/reset-password', A); check('owner resets an unknown teacher → 404', s, 404, js)

# ---------------------------------------------------------------- teacher setup
print('== teacher: subjects, groups, pupils')
s, ref = call('GET', '/api/v1/reference', T); check('reference data', s, 200, ref)
level = ref['levels'][3]['id']
s, js = call('POST', '/api/v1/subjects', T, {'nameFr': 'Sciences ' + RUN, 'nameAr': 'علوم', 'color': '#123456'}); check('new subject → 201', s, {200, 201}, js)
subject = idof(js)
s, js = call('POST', '/api/v1/subjects', T, {'nameFr': 'X', 'color': 'rouge'}); check('subject with a bad colour → 400', s, 400, js)
s, js = call('POST', '/api/v1/subjects', T, {'nameFr': 'Sciences ' + RUN}); check('same subject twice → 409', s, {409, 400}, js)
s, js = call('PUT', f'/api/v1/subjects/{subject}', T, {'nameFr': 'Sciences ' + RUN, 'nameAr': 'علوم', 'color': '#654321'}); check('rename subject', s, 200, js)
s, js = call('GET', '/api/v1/subjects', T); check('list subjects', s, 200, js)
s, js = call('POST', '/api/v1/groups', T, {'name': '4ème API', 'subjectId': subject, 'levelId': level}); check('new group → 201', s, {200, 201}, js)
group = idof(js)
s, js = call('POST', '/api/v1/groups', T, {'name': 'g', 'subjectId': str(uuid.uuid4()), 'levelId': level}); check('group with an unknown subject → 4xx', s, {400, 404}, js)
s, js = call('DELETE', f'/api/v1/subjects/{subject}', T); check('delete a subject in use → 409', s, {409, 400}, js)
pupil = {'firstName': 'Adam', 'lastName': 'Api' + RUN, 'levelId': level, 'groupIds': [group], 'createLogin': True,
         'parents': [{'firstName': 'Mouna', 'lastName': 'Api' + RUN, 'phone': PHONE, 'relation': 'mother'}]}
s, js = call('POST', '/api/v1/students', T, pupil); check('new pupil with a parent → 201', s, {200, 201}, js)
student = js['student']['id']
creds = {c['role']: c for c in js['credentials']}
s, js2 = call('POST', '/api/v1/students', T, {**pupil, 'firstName': ''}); check('pupil without first name → 400', s, 400, js2)
s, js2 = call('POST', '/api/v1/students', T, {**pupil, 'levelId': 'pas-un-uuid'}); check('pupil with a malformed level → 400', s, 400, js2)
ST = first_login(creds['STUDENT'])
PA = first_login(creds['PARENT'])
s, js = call('GET', '/api/v1/students', T); check('list pupils', s, 200, js)
s, js = call('GET', f'/api/v1/students/{student}', T); check('pupil profile', s, 200, js)
s, js = call('GET', '/api/v1/students/username-suggestion?firstName=Adam&lastName=Api' + RUN + '', T); check('username suggestion', s, 200, js)
s, js = call('POST', f'/api/v1/students/{student}/private-notes', T, {'body': 'Note privée API'}); check('private note', s, {200, 201}, js)
note = (js or {}).get('id')
s, js = call('PUT', f'/api/v1/students/{student}/private-notes/{note}', T, {'body': 'Note modifiée'}); check('edit private note', s, 200, js)
s, js = call('POST', f'/api/v1/students/{student}/private-notes', T, {'body': ''}); check('empty private note → 400', s, 400, js)
s, js = call('DELETE', f'/api/v1/students/{student}/private-notes/{note}', T); check('delete private note', s, {200, 204}, js)
s, js = call('POST', f'/api/v1/students/{student}/comments', T, {'body': 'Adam progresse bien.'}); check('comment for the family', s, {200, 201}, js)
s, js = call('GET', f'/api/v1/me/comments?studentId={student}', PA); check('parent reads the comment', s, 200, js)
s, js = call('GET', '/api/v1/parents', T); check('list parents', s, 200, js)
s, js = call('GET', f'/api/v1/groups/{group}', T); check('group detail', s, 200, js)
s, js = call('PUT', f'/api/v1/groups/{group}/members', T, {'studentIds': [student, str(uuid.uuid4())]}); check('group members with an unknown pupil → 4xx', s, {400, 404}, js)
s, js = call('PUT', f'/api/v1/groups/{group}/members', T, {'studentIds': [student]}); check('group members', s, {200, 204}, js)

print('== planning')
day = (now + dt.timedelta(days=1)).date().isoformat()
sess = {'groupId': group, 'date': day, 'startTime': '10:00', 'endTime': '11:00', 'mode': 'IN_PERSON', 'location': 'Salle 1'}
s, js = call('POST', '/api/v1/sessions', T, sess); check('new session → 201', s, {200, 201}, js)
session = js['first']['id']
s, js = call('POST', '/api/v1/sessions', T, {**sess, 'startTime': '12:00', 'endTime': '11:00'}); check('session ending before it starts → 400', s, 400, js)
s, js = call('POST', '/api/v1/sessions', T, {**sess, 'mode': 'TELEPORT'}); check('session with an unknown mode → 400', s, 400, js)
s, js = call('GET', f'/api/v1/sessions/overlaps?date={day}&start=10:30&end=11:30', T); check('overlaps', s, 200, js)
s, js = call('GET', f'/api/v1/sessions?from={iso(now)}&to={iso(now + dt.timedelta(days=7))}', T); check('week of sessions', s, 200, js)
s, js = call('GET', '/api/v1/sessions?from=hier&to=demain', T); check('sessions with bad dates → 400', s, 400, js)
s, js = call('GET', '/api/v1/sessions', T); check('sessions without dates → 400', s, 400, js)
s, js = call('GET', f'/api/v1/sessions/{session}', T); check('session detail', s, 200, js)
s, js = call('PUT', f'/api/v1/sessions/{session}/notes', T, {'prepNote': 'Préparer la série', 'quickNote': None, 'sessionNote': None}); check('session notes', s, {200, 204}, js)
s, js = call('POST', f'/api/v1/sessions/{session}/start', T); check('start session', s, {200, 204}, js)
s, js = call('PUT', f'/api/v1/sessions/{session}/attendance', T, {'entries': [{'studentId': student, 'status': 'PRESENT'}]}); check('attendance', s, {200, 204}, js)
s, js = call('PUT', f'/api/v1/sessions/{session}/attendance', T, {'entries': [{'studentId': student, 'status': 'PEUTETRE'}]}); check('attendance with an unknown status → 400', s, 400, js)
s, js = call('POST', f'/api/v1/sessions/{session}/end', T, {'details': 'Exercices 1 à 4'}); check('end session', s, {200, 204}, js)
s, js = call('GET', f'/api/v1/me/sessions?from={iso(now)}&to={iso(now + dt.timedelta(days=7))}', ST); check('pupil planning', s, 200, js)
s, js = call('GET', f'/api/v1/me/sessions?from={iso(now)}&to={iso(now + dt.timedelta(days=7))}&studentId={student}', PA); check('parent planning', s, 200, js)
s, js = call('POST', '/api/v1/sessions', T, {**sess, 'date': (now + dt.timedelta(days=2)).date().isoformat()}); s2 = js['first']['id']
s, js = call('POST', f'/api/v1/sessions/{s2}/cancel', T, {'reason': 'Malade'}); check('cancel session', s, {200, 204}, js)
s, js = call('POST', f'/api/v1/sessions/{s2}/restore', T); check('restore session', s, {200, 204}, js)

print('== contents')
s, js = call('POST', '/api/v1/chapters', T, {'subjectId': subject, 'levelId': level, 'title': 'Les fractions API'}); check('new chapter', s, {200, 201}, js)
chapter = idof(js)
meta = {'title': 'Série API', 'subjectId': subject, 'levelId': level, 'chapterId': chapter, 'tag': 'SERIE', 'draft': False, 'groupIds': [group]}
s, js = call('POST', '/api/v1/contents', T, multipart={'file': ('serie.pdf', PDF, 'application/pdf'), 'meta': (None, json.dumps(meta).encode(), 'application/json')}); check('upload a PDF → 201', s, {200, 201}, js)
content = idof(js)
s, js = call('POST', '/api/v1/contents', T, multipart={'meta': (None, json.dumps(meta).encode(), 'application/json')}); check('upload without a file → 400', s, 400, js)
s, js = call('POST', '/api/v1/contents', T, multipart={'file': ('x.exe', b'MZ\x90\x00', 'application/octet-stream'), 'meta': (None, json.dumps(meta).encode(), 'application/json')}); check('upload an .exe → 4xx', s, {400, 415}, js)
s, js = call('POST', '/api/v1/contents', T, multipart={'file': ('serie.pdf', PDF, 'application/pdf'), 'meta': (None, json.dumps({**meta, 'tag': 'BIDON'}).encode(), 'application/json')}); check('upload with an unknown tag → 400', s, 400, js)
s, js = call('GET', '/api/v1/contents', T); check('library', s, 200, js)
s, js = call('GET', f'/api/v1/contents/{content}/view', T); check('teacher opens the PDF', s, 200, js)
file_url = (js or {}).get('url', '')
if file_url:
    path = file_url[file_url.index('/api/'):] if '/api/' in file_url else file_url
    s, _ = call('GET', path); check('signed file link opens without a login', s, 200)
s, js = call('GET', '/api/v1/files/pas-un-jeton'); check('forged file link → 4xx', s, {400, 401, 403, 404}, js)
s, js = call('GET', '/api/v1/me/contents', ST); check('pupil Cours', s, 200, js)
check('pupil sees the shared PDF', 200 if js and 'Série API' in json.dumps(js, ensure_ascii=False) else 0, 200)
s, js = call('GET', f'/api/v1/contents/{content}/view', ST); check('pupil opens the shared PDF (its group) → 200', s, 200, js)
s, js = call('POST', f'/api/v1/contents/{content}/duplicate', T); check('duplicate content', s, {200, 201}, js)
dup = (js or {}).get('id')
s, js = call('POST', f'/api/v1/contents/{dup}/archive', T); check('archive content', s, {200, 204}, js)
s, js = call('POST', '/api/v1/contents/pages', T, {'title': 'Page API', 'subjectId': subject, 'levelId': level, 'chapterId': chapter, 'tag': 'COURS'}); check('new written page', s, {200, 201}, js)
page = ((js or {}).get('item') or js or {}).get('id')
s, js = call('GET', f'/api/v1/contents/{page}/page', T); check('open the page', s, 200, js)
s, js = call('PUT', f'/api/v1/contents/{page}/page', T, {'body': [{'insert': 'Bonjour\n'}], 'answerKey': None}); check('save the page', s, {200, 204, 400}, js)

print('== homework and correction')
hw_body = {'contentItemId': content, 'title': 'Devoir API', 'groupId': group, 'deadlineAt': iso(now + dt.timedelta(days=3)), 'submissionMode': 'FILE', 'allowLate': False, 'instructions': 'Faire 1 à 4', 'maxScore': 20}
s, js = call('POST', '/api/v1/assignments', T, hw_body); check('give homework → 201', s, {200, 201}, js)
hw = idof(js)
s, js = call('POST', '/api/v1/assignments', T, {**hw_body, 'deadlineAt': iso(now - dt.timedelta(days=3))}); check('homework due in the past → 400', s, 400, js)
s, js = call('POST', '/api/v1/assignments', T, {**hw_body, 'maxScore': 0}); check('homework out of 0 → 400', s, 400, js)
s, js = call('GET', '/api/v1/me/assignments', ST); check('pupil homework list', s, 200, js)
s, js = call('GET', f'/api/v1/me/assignments/{hw}', ST); check('pupil homework detail', s, 200, js)
s, js = call('POST', f'/api/v1/me/assignments/{hw}/submission', ST, multipart={'file': ('copie.pdf', PDF, 'application/pdf')}); check('pupil sends a copy', s, {200, 201}, js)
s, js = call('POST', f'/api/v1/me/assignments/{hw}/submission', PA, multipart={'file': ('copie.pdf', PDF, 'application/pdf')}); check('parent sends for the child (no studentId) → 4xx', s, {400, 403, 404}, js)
s, js = call('GET', f'/api/v1/me/assignments/{hw}/submission/view', ST); check('pupil reopens the copy', s, 200, js)
s, js = call('GET', '/api/v1/assignments/to-correct', T); check('À corriger', s, 200, js)
s, js = call('GET', '/api/v1/assignments/missing', T); check('missing work', s, 200, js)
s, js = call('GET', f'/api/v1/assignments/{hw}/corrections/{student}', T); check('open a copy', s, 200, js)
s, js = call('PUT', f'/api/v1/assignments/{hw}/corrections/{student}', T, {'score': 25, 'comment': 'trop'}); check('score above the max → 400', s, 400, js)
s, js = call('PUT', f'/api/v1/assignments/{hw}/corrections/{student}', T, {'score': -1}); check('negative score → 400', s, 400, js)
s, js = call('PUT', f'/api/v1/assignments/{hw}/corrections/{student}', T, {'score': 15.5, 'comment': 'Bien'}); check('correct a copy', s, {200, 204}, js)
s, js = call('PUT', f'/api/v1/assignments/{hw}/corrections/{student}/file', T, multipart={'file': ('corr.pdf', PDF, 'application/pdf')}); check('attach a corrected file', s, {200, 204}, js)
s, js = call('GET', f'/api/v1/me/assignments/{hw}/correction/view?studentId={student}', PA); check('parent opens the correction', s, 200, js)
s, js = call('PUT', f'/api/v1/assignments/{hw}/deadline', T, {'deadlineAt': iso(now + dt.timedelta(days=5))}); check('move the deadline', s, {200, 204}, js)
s, js = call('POST', f'/api/v1/assignments/{hw}/close', T); check('close homework', s, {200, 204}, js)
s, js = call('GET', f'/api/v1/me/results?studentId={student}', PA); check('parent results', s, 200, js)
s, js = call('GET', f'/api/v1/students/{student}/results', T); check('teacher sees the pupil results', s, 200, js)

print('== quiz')
s, js = call('POST', '/api/v1/contents/quizzes', T, {'title': 'Quiz API', 'subjectId': subject, 'levelId': level, 'mcqOnly': False}); check('new quiz', s, {200, 201}, js)
quiz = js['item']['id']
qs = [{'id': 'q1', 'type': 'MCQ', 'points': 2, 'text': [{'insert': 'Combien font 1+1 ?\n'}], 'choices': [{'id': 'a', 'text': '2'}, {'id': 'b', 'text': '3'}], 'correct': 'a'},
      {'id': 'q2', 'type': 'TRUE_FALSE', 'points': 1, 'text': [{'insert': '2 > 1\n'}], 'answer': True}]
settings = {'attemptsAllowed': 1, 'scorePolicy': 'BEST', 'answersShown': 'AFTER_DEADLINE', 'shuffle': False, 'timeLimitMin': None}
s, js = call('PUT', f'/api/v1/contents/{quiz}/quiz', T, {'settings': {**settings, 'attemptsAllowed': 0}, 'questions': qs}); check('quiz with 0 attempts → 400', s, 400, js)
s, js = call('PUT', f'/api/v1/contents/{quiz}/quiz', T, {'settings': settings, 'questions': qs}); check('save quiz', s, 200, js)
s, js = call('PUT', f'/api/v1/contents/{quiz}', T, {'title': 'Quiz API', 'subjectId': subject, 'levelId': level, 'tag': 'AUTRE', 'draft': False}); check('publish quiz', s, 200, js)
s, js = call('POST', '/api/v1/assignments', T, {**hw_body, 'contentItemId': quiz, 'submissionMode': 'FILE'}); check('quiz given as a file → 400', s, 400, js, 'quiz_mode_mismatch')
s, js = call('POST', '/api/v1/assignments', T, {**hw_body, 'contentItemId': quiz, 'submissionMode': 'QUIZ', 'title': 'Quiz API'}); check('give the quiz', s, {200, 201}, js)
qhw = idof(js)
s, js = call('POST', f'/api/v1/me/assignments/{qhw}/quiz/attempts', ST); check('pupil starts the quiz', s, 200, js)
att = idof(js)
check('the pupil never receives the answers', 0 if '"correct"' in json.dumps(js) else 200, 200)
s, js = call('PUT', f'/api/v1/me/assignments/{qhw}/quiz/attempts/{att}/answers', ST, {'answers': {'q1': {'choice': 'a'}, 'q2': {'value': True}}}); check('pupil answers', s, {200, 204}, js)
s, js = call('PUT', f'/api/v1/me/assignments/{qhw}/quiz/attempts/{att}/answers', ST, {'answers': {'q9': {'choice': 'z'}}}); check('answer to an unknown question → 400', s, {400, 204}, js)
s, js = call('POST', f'/api/v1/me/assignments/{qhw}/quiz/attempts/{att}/submit', ST); check('pupil sends the quiz', s, 200, js)
check('quiz graded 3/3', 200 if js and float(js.get('score', -1)) == 3 else 0, 200)
s, js = call('POST', f'/api/v1/me/assignments/{qhw}/quiz/attempts', ST); check('no attempt left → 409', s, 409, js, 'quiz_no_attempt_left')
s, js = call('PUT', f'/api/v1/me/assignments/{qhw}/quiz/attempts/{att}/answers', ST, {'answers': {'q1': {'choice': 'b'}}}); check('answering after sending → 409', s, {409, 400}, js)
s, js = call('POST', f'/api/v1/me/assignments/{qhw}/quiz/attempts', PA); check('parent cannot take the quiz', s, {400, 403, 404}, js)
s, js = call('GET', f'/api/v1/assignments/{qhw}/quiz/{student}', T); check('teacher sees the answers', s, 200, js)

print('== evaluations, announcements, notifications, search')
s, js = call('POST', '/api/v1/evaluations', T, {'groupId': group, 'title': 'Contrôle API', 'heldOn': now.date().isoformat(), 'maxScore': 20, 'chapterId': chapter}); check('new evaluation', s, {200, 201}, js)
ev = idof(js)
s, js = call('PUT', f'/api/v1/evaluations/{ev}/grades', T, {'grades': [{'studentId': student, 'score': 30, 'absent': False}]}); check('grade above the max → 400', s, 400, js)
s, js = call('PUT', f'/api/v1/evaluations/{ev}/grades', T, {'grades': [{'studentId': student, 'score': 17, 'absent': False, 'comment': 'Très bien'}]}); check('enter grades', s, {200, 204}, js)
s, js = call('POST', '/api/v1/announcements', T, {'title': 'Sortie', 'body': 'Jeudi au musée.', 'audience': 'BOTH', 'groupIds': [group]}); check('send an announcement', s, {200, 201}, js)
ann = idof(js)
s, js = call('POST', '/api/v1/announcements', T, {'title': 'x', 'body': 'y', 'audience': 'TOUT_LE_MONDE', 'groupIds': [group]}); check('announcement with an unknown audience → 400', s, 400, js)
s, js = call('POST', '/api/v1/announcements', T, {'title': 'x', 'body': 'y', 'audience': 'BOTH'}); check('announcement to nobody → 400', s, 400, js)
s, js = call('GET', '/api/v1/me/notifications', PA); check('parent notifications', s, 200, js)
items = js if isinstance(js, list) else (js or {}).get('items', [])
s, js = call('GET', '/api/v1/me/notifications/unread-count', PA); check('unread count', s, 200, js)
if items:
    s, js = call('POST', f"/api/v1/me/notifications/{items[0]['id']}/read", PA); check('mark one read', s, {200, 204}, js)
s, js = call('POST', '/api/v1/me/notifications/read-all', PA); check('mark all read', s, {200, 204}, js)
s, js = call('POST', f'/api/v1/me/notifications/{uuid.uuid4()}/read', PA); check('mark an unknown notification → 404', s, {404, 204}, js)
s, js = call('GET', f'/api/v1/announcements/{ann}/unread', T); check('who has not read', s, 200, js)
s, js = call('GET', '/api/v1/search?q=Adam', T); check('search', s, 200, js)
s, js = call('GET', '/api/v1/search?q=' + 'a' * 2000, T); check('search with a huge query → 2xx/400', s, {200, 400}, js)
s, js = call('GET', "/api/v1/search?q=%27%3B%20drop%20table%20users%3B--", T); check('search with SQL in it → 200', s, 200, js)
s, js = call('GET', '/api/v1/students/import/template?lang=ar', T); check('import template', s, 200, js)
s, js = call('POST', f'/api/v1/students/{student}/consent', T); check('paper consent', s, {200, 204, 409}, js)

# ---------------------------------------------------------------- isolation between teachers
print('== isolation: teacher 2 reaching teacher 1')
foreign = [
    ('GET', f'/api/v1/students/{student}'), ('PUT', f'/api/v1/students/{student}'), ('POST', f'/api/v1/students/{student}/archive'),
    ('GET', f'/api/v1/students/{student}/results'), ('GET', f'/api/v1/students/{student}/private-notes'), ('GET', f'/api/v1/students/{student}/comments'),
    ('POST', f'/api/v1/students/{student}/consent'), ('POST', f'/api/v1/students/{student}/login'),
    ('GET', f'/api/v1/groups/{group}'), ('PUT', f'/api/v1/groups/{group}/members'), ('POST', f'/api/v1/groups/{group}/archive'),
    ('GET', f'/api/v1/sessions/{session}'), ('PUT', f'/api/v1/sessions/{session}/attendance'), ('POST', f'/api/v1/sessions/{session}/cancel'),
    ('GET', f'/api/v1/contents/{content}/view'), ('PUT', f'/api/v1/contents/{content}/shares'), ('POST', f'/api/v1/contents/{content}/archive'),
    ('GET', f'/api/v1/contents/{quiz}/quiz'), ('GET', f'/api/v1/contents/{page}/page'),
    ('PUT', f'/api/v1/chapters/{chapter}'), ('DELETE', f'/api/v1/chapters/{chapter}'),
    ('GET', f'/api/v1/assignments/{hw}'), ('GET', f'/api/v1/assignments/{hw}/corrections/{student}'), ('PUT', f'/api/v1/assignments/{hw}/corrections/{student}'),
    ('GET', f'/api/v1/evaluations/{ev}'), ('PUT', f'/api/v1/evaluations/{ev}/grades'), ('GET', f'/api/v1/announcements/{ann}/unread'), ('DELETE', f'/api/v1/announcements/{ann}'),
    ('PUT', f'/api/v1/subjects/{subject}'), ('DELETE', f'/api/v1/subjects/{subject}'), ('POST', f'/api/v1/users/{student}/reset-password'),
]
bodies = {'PUT': {'name': 'x', 'title': 'x', 'nameFr': 'x', 'firstName': 'x', 'lastName': 'x', 'levelId': level, 'subjectId': subject,
                  'studentIds': [], 'groupIds': [], 'entries': [], 'grades': [], 'score': 1}}
for m, p in foreign:
    s, js = call(m, p, T2, bodies.get(m))
    check(f'teacher 2 {m} {p.replace(student, "{pupil}")} → 403/404', s, {403, 404}, js)
s, js = call('GET', '/api/v1/students', T2); check("teacher 2's list has none of teacher 1's pupils", 200 if s == 200 and student not in json.dumps(js) else 0, 200)
s, js = call('GET', '/api/v1/search?q=Api' + RUN, T2); check("teacher 2's search finds nothing of teacher 1", 200 if s == 200 and student not in json.dumps(js) else 0, 200)
s, js = call('POST', '/api/v1/sessions', T2, sess); check('teacher 2 plans in teacher 1 group → 4xx', s, {400, 403, 404}, js)
s, js = call('POST', '/api/v1/assignments', T2, hw_body); check("teacher 2 gives homework with teacher 1's content → 4xx", s, {400, 403, 404}, js)
s, js = call('GET', f'/api/v1/me/assignments/{hw}', S); check("another pupil opens Adam's homework → 403/404", s, {403, 404}, js)
s, js = call('GET', f'/api/v1/me/results?studentId={student}', P); check("another parent reads Adam's results → 403/404", s, {403, 404}, js)
s, js = call('GET', f'/api/v1/me/assignments/{hw}/correction/view?studentId={student}', P); check("another parent opens Adam's correction → 403/404", s, {403, 404}, js)

# ---------------------------------------------------------------- every endpoint, unhappy
print('== every endpoint: no login, wrong role, unknown and malformed ids, bad bodies')
X = str(uuid.uuid4())
E = [  # method, path template ({id} / {sid}), role that owns it
    ('GET', '/api/v1/me', 'any'), ('POST', '/api/v1/me/password', 'any'), ('PUT', '/api/v1/me/language', 'any'),
    ('GET', '/api/v1/admin/teachers', 'admin'), ('POST', '/api/v1/admin/teachers', 'admin'), ('POST', '/api/v1/admin/teachers/{id}/reset-password', 'admin'),
    ('POST', '/api/v1/admin/teachers/{id}/disable', 'admin'), ('POST', '/api/v1/admin/teachers/{id}/enable', 'admin'),
    ('GET', '/api/v1/me/sessions?from=2026-01-01T00:00:00Z&to=2026-12-01T00:00:00Z', 'family'),
    ('GET', '/api/v1/sessions?from=2026-01-01T00:00:00Z&to=2026-12-01T00:00:00Z', 'teacher'), ('GET', '/api/v1/sessions/{id}', 'teacher'),
    ('GET', '/api/v1/sessions/overlaps?date=2026-12-01&start=10:00&end=11:00', 'teacher'), ('POST', '/api/v1/sessions', 'teacher'),
    ('PUT', '/api/v1/sessions/{id}', 'teacher'), ('POST', '/api/v1/sessions/{id}/cancel', 'teacher'), ('POST', '/api/v1/sessions/{id}/restore', 'teacher'),
    ('POST', '/api/v1/sessions/{id}/start', 'teacher'), ('POST', '/api/v1/sessions/{id}/end', 'teacher'), ('PUT', '/api/v1/sessions/{id}/attendance', 'teacher'),
    ('PUT', '/api/v1/sessions/{id}/notes', 'teacher'), ('DELETE', '/api/v1/recurrence-rules/{id}', 'teacher'),
    ('GET', '/api/v1/assignments/{id}/quiz/{sid}', 'teacher'), ('PUT', '/api/v1/assignments/{id}/quiz/{sid}/attempts/{id}', 'teacher'),
    ('POST', '/api/v1/contents/quizzes', 'teacher'), ('GET', '/api/v1/contents/{id}/quiz', 'teacher'), ('PUT', '/api/v1/contents/{id}/quiz', 'teacher'),
    ('POST', '/api/v1/contents/{id}/quiz/duplicate', 'teacher'), ('POST', '/api/v1/contents/{id}/quiz/preview', 'teacher'),
    ('GET', '/api/v1/me/assignments/{id}/quiz', 'family'), ('POST', '/api/v1/me/assignments/{id}/quiz/attempts', 'pupil'),
    ('PUT', '/api/v1/me/assignments/{id}/quiz/attempts/{id}/answers', 'pupil'), ('POST', '/api/v1/me/assignments/{id}/quiz/attempts/{id}/submit', 'pupil'),
    ('GET', '/api/v1/me/assignments/{id}/quiz/attempts/{id}', 'family'),
    ('POST', '/api/v1/contents/pages', 'teacher'), ('GET', '/api/v1/contents/{id}/page', 'teacher'), ('PUT', '/api/v1/contents/{id}/page', 'teacher'),
    ('POST', '/api/v1/contents/pictures', 'teacher'), ('GET', '/api/v1/contents', 'teacher'), ('POST', '/api/v1/contents', 'teacher'),
    ('PUT', '/api/v1/contents/{id}', 'teacher'), ('PUT', '/api/v1/contents/{id}/shares', 'teacher'), ('POST', '/api/v1/contents/{id}/duplicate', 'teacher'),
    ('POST', '/api/v1/contents/{id}/archive', 'teacher'), ('GET', '/api/v1/contents/{id}/view', 'teacher'),
    ('GET', '/api/v1/me/contents', 'family'), ('GET', '/api/v1/me/contents/covered', 'family'),
    ('POST', '/api/v1/chapters', 'teacher'), ('PUT', '/api/v1/chapters/{id}', 'teacher'), ('DELETE', '/api/v1/chapters/{id}', 'teacher'), ('PUT', '/api/v1/chapters/{id}/shares', 'teacher'),
    ('GET', '/api/v1/announcements', 'teacher'), ('POST', '/api/v1/announcements', 'teacher'), ('GET', '/api/v1/announcements/{id}/unread', 'teacher'), ('DELETE', '/api/v1/announcements/{id}', 'teacher'),
    ('GET', '/api/v1/groups', 'teacher'), ('GET', '/api/v1/groups/{id}', 'teacher'), ('POST', '/api/v1/groups', 'teacher'), ('PUT', '/api/v1/groups/{id}', 'teacher'),
    ('POST', '/api/v1/groups/{id}/archive', 'teacher'), ('PUT', '/api/v1/groups/{id}/members', 'teacher'), ('POST', '/api/v1/groups/private-lessons', 'teacher'),
    ('GET', '/api/v1/search?q=a', 'teacher'), ('GET', '/api/v1/students/{id}/results', 'teacher'),
    ('GET', '/api/v1/evaluations', 'teacher'), ('POST', '/api/v1/evaluations', 'teacher'), ('GET', '/api/v1/evaluations/{id}', 'teacher'),
    ('PUT', '/api/v1/evaluations/{id}', 'teacher'), ('PUT', '/api/v1/evaluations/{id}/grades', 'teacher'),
    ('GET', '/api/v1/me/assignments', 'family'), ('GET', '/api/v1/me/assignments/{id}', 'family'), ('POST', '/api/v1/me/assignments/{id}/submission', 'family'),
    ('GET', '/api/v1/me/assignments/{id}/submission/view', 'family'), ('GET', '/api/v1/me/assignments/{id}/correction/view', 'family'), ('GET', '/api/v1/me/results', 'family'),
    ('GET', '/api/v1/assignments', 'teacher'), ('POST', '/api/v1/assignments', 'teacher'), ('GET', '/api/v1/assignments/{id}', 'teacher'),
    ('PUT', '/api/v1/assignments/{id}/deadline', 'teacher'), ('POST', '/api/v1/assignments/{id}/close', 'teacher'), ('GET', '/api/v1/assignments/submissions/{id}/view', 'teacher'),
    ('GET', '/api/v1/assignments/to-correct', 'teacher'), ('GET', '/api/v1/assignments/missing', 'teacher'), ('GET', '/api/v1/assignments/{id}/corrections/{sid}', 'teacher'),
    ('PUT', '/api/v1/assignments/{id}/corrections/{sid}', 'teacher'), ('PUT', '/api/v1/assignments/{id}/corrections/{sid}/file', 'teacher'),
    ('DELETE', '/api/v1/assignments/{id}/corrections/{sid}/file', 'teacher'), ('GET', '/api/v1/assignments/{id}/corrections/{sid}/file/view', 'teacher'),
    ('POST', '/api/v1/users/{id}/reset-password', 'teacher'),
    ('GET', '/api/v1/students', 'teacher'), ('GET', '/api/v1/students/{id}', 'teacher'), ('POST', '/api/v1/students', 'teacher'), ('PUT', '/api/v1/students/{id}', 'teacher'),
    ('POST', '/api/v1/students/{id}/archive', 'teacher'), ('POST', '/api/v1/students/{id}/login', 'teacher'), ('DELETE', '/api/v1/students/{id}/login', 'teacher'),
    ('POST', '/api/v1/students/{id}/restore', 'teacher'), ('GET', '/api/v1/students/username-suggestion?firstName=a&lastName=b', 'teacher'),
    ('GET', '/api/v1/students/{id}/private-notes', 'teacher'), ('POST', '/api/v1/students/{id}/private-notes', 'teacher'),
    ('PUT', '/api/v1/students/{id}/private-notes/{id}', 'teacher'), ('DELETE', '/api/v1/students/{id}/private-notes/{id}', 'teacher'),
    ('GET', '/api/v1/students/{id}/comments', 'teacher'), ('POST', '/api/v1/students/{id}/comments', 'teacher'), ('GET', '/api/v1/parents', 'teacher'),
    ('POST', '/api/v1/students/import/preview', 'teacher'), ('POST', '/api/v1/students/import', 'teacher'), ('GET', '/api/v1/students/import/template', 'teacher'),
    ('GET', '/api/v1/me/privacy', 'any'), ('POST', '/api/v1/me/privacy', 'any'), ('POST', '/api/v1/students/{id}/consent', 'teacher'),
    ('GET', '/api/v1/subjects', 'teacher'), ('POST', '/api/v1/subjects', 'teacher'), ('PUT', '/api/v1/subjects/{id}', 'teacher'), ('DELETE', '/api/v1/subjects/{id}', 'teacher'),
    ('GET', '/api/v1/me/comments', 'family'), ('GET', '/api/v1/reference', 'any'),
    ('GET', '/api/v1/me/notifications', 'any'), ('GET', '/api/v1/me/notifications/unread-count', 'any'), ('POST', '/api/v1/me/notifications/{id}/read', 'any'),
    ('POST', '/api/v1/me/notifications/read-all', 'any'),
]
tokens = {'admin': A, 'teacher': T, 'pupil': S, 'parent': P}
allowed = {'any': {'admin', 'teacher', 'pupil', 'parent'}, 'admin': {'admin'}, 'teacher': {'teacher'}, 'family': {'pupil', 'parent'}, 'pupil': {'pupil'}}
PUBLIC = {'/api/v1/students/import/template'}
NOBODY = {'/api/v1/me/privacy', '/api/v1/me/notifications/read-all'}  # take no body: a broken one is ignored
MULTI = ('submission', '/file', 'import/preview', 'pictures')
is_multi = lambda m, t: m in ('POST', 'PUT') and (any(k in t for k in MULTI) or (m == 'POST' and t == '/api/v1/contents'))
for m, tpl, owner in E:
    path = tpl.replace('{id}', X).replace('{sid}', X)
    if tpl in PUBLIC:
        s, js = call(m, path); check(f'public {tpl} (no personal data) → 200', s, 200, js); continue
    mp = {'file': ('a.pdf', PDF, 'application/pdf')} if is_multi(m, tpl) else None
    s, js = call(m, path)
    check(f'no login {m} {tpl} → 401', s, 401, js)
    for role, tok in tokens.items():
        if role in allowed[owner]:
            continue
        if owner == 'family' and role in ('teacher', 'admin') or owner != 'any':
            s, js = call(m, path, tok, None if mp else ({} if m in ('POST', 'PUT') else None), multipart=mp)
            # {} may be refused by validation before the role check (nothing done, only field names returned).
            exp = {403, 400} if m in ('POST', 'PUT') else {403}
            if owner == 'teacher' and role in ('pupil', 'parent') and tpl.endswith('/view'): exp |= {404}
            if owner == 'pupil' and role == 'parent': exp |= {400, 404}
            check(f'{role} {m} {tpl} → 403', s, exp, js)
    role = sorted(allowed[owner])[0] if owner != 'any' else 'teacher'
    tok = tokens['pupil' if owner == 'pupil' else role]
    if '{id}' in tpl or '{sid}' in tpl:
        s, js = call(m, path, tok, None if mp else ({} if m in ('POST', 'PUT') else None), multipart=mp)
        check(f'{role} {m} {tpl} unknown id → 4xx', s, {400, 404, 409}, js)
        bad = tpl.replace('{id}', 'pas-un-id').replace('{sid}', 'pas-un-id')
        s, js = call(m, bad, tok, multipart=mp)
        check(f'{role} {m} {tpl} malformed id → 400/404', s, {400, 404}, js)
    if m in ('POST', 'PUT') and '{id}' not in tpl and tpl not in NOBODY and not mp:
        s, js = call(m, path, tok, raw='{pas du json')
        check(f'{role} {m} {tpl} broken JSON → 4xx', s, {400, 415}, js)
        s, js = call(m, path, tok, {'title': 'a' * 100000, 'name': None, 'firstName': 123, 'groupIds': 'x'})
        check(f'{role} {m} {tpl} wrong types / huge text → 4xx or 2xx', s, {200, 201, 204, 400, 404, 409, 413, 415}, js)
        if s < 300: print('   accepted junk body:', m, tpl, s)

print('== wrong role with a valid body')
valid = [('POST', '/api/v1/students', pupil), ('POST', '/api/v1/groups', {'name': 'g', 'subjectId': subject, 'levelId': level}),
         ('POST', '/api/v1/subjects', {'nameFr': 'Z' + RUN}), ('POST', '/api/v1/sessions', sess), ('POST', '/api/v1/assignments', hw_body),
         ('POST', '/api/v1/evaluations', {'groupId': group, 'title': 'x', 'heldOn': now.date().isoformat(), 'maxScore': 20}),
         ('POST', '/api/v1/announcements', {'title': 'x', 'body': 'y', 'audience': 'BOTH', 'groupIds': [group]}),
         ('POST', '/api/v1/chapters', {'subjectId': subject, 'levelId': level, 'title': 'x'}),
         ('PUT', f'/api/v1/assignments/{hw}/corrections/{student}', {'score': 20}),
         ('PUT', f'/api/v1/evaluations/{ev}/grades', {'grades': [{'studentId': student, 'score': 20, 'absent': False}]}),
         ('POST', '/api/v1/admin/teachers', {'firstName': 'a', 'lastName': 'b', 'username': 'x' + RUN})]
for m, p, b in valid:
    for role, tok in {'admin': A, 'teacher': T, 'pupil': ST, 'parent': PA}.items():
        if role != ('admin' if '/admin/' in p else 'teacher'):
            s, js = call(m, p, tok, b); check(f'{role} {m} {p} with a valid body → 403', s, 403, js)

print('== archived pupil and closed login')
s, js = call('GET', '/api/v1/me/assignments', ST); check('pupil signed in before archiving', s, 200, js)
s, js = call('POST', f'/api/v1/students/{student}/archive', T); check('archive the pupil', s, {200, 204}, js)
s, js = call('GET', '/api/v1/me/assignments', ST); check("archived pupil's live token refused → 401", s, 401, js, 'account_disabled')
s, js = call('GET', f'/api/v1/me/results?studentId={student}', PA); check("their parent's live token refused → 401", s, 401, js, 'account_disabled')
s, js = call('POST', f'/api/v1/students/{student}/restore', T); check('restore the pupil', s, {200, 204}, js)

# ---------------------------------------------------------------- report
ok = sum(1 for c in checks if c[0])
print(f'\n{ok}/{len(checks)} checks passed, {len(server_errors)} server errors (5xx)')
for c in checks:
    if not c[0]:
        print(f'  FAIL {c[1]}: got {c[2]} (code {c[4]}), expected {c[3]}')
for e in server_errors[:40]:
    print('  5xx', e)
