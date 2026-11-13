"""Release 4: the end of a session (spec 03, "End of session") and the progress charts (spec 07, "Charts")."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'r2' / '_generator'))

from contents import square  # noqa: E402  (also puts the R1 generator on the path)

import common  # noqa: E402
from common import ACCENTS, avatar, badge, chip, icon, page  # noqa: E402
from planning import phone  # noqa: E402
from teacher_notifications import TEACHER_NAV  # noqa: E402

OUT = Path(__file__).resolve().parents[1]

common.ICONS.update({
    'checksquare': '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="m8 12 3 3 5-6"/>',
    'filetext': '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4M10 9H8M16 13H8M16 17H8"/>',
    'listchecks': '<path d="m3 17 2 2 4-4M3 7l2 2 4-4M13 6h8M13 12h8M13 18h8"/>',
    'flag': '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><path d="M4 22v-7"/>',
    'table': '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18"/>',
    'trendup': '<path d="m22 7-8.5 8.5-5-5L2 17"/><path d="M16 7h6v6"/>',
    'eye': '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
})

INDIGO, TURQUOISE, ORANGE = '#2B3990', '#12A39A', '#E8590C'
GRID, AXIS, INK, MUTED = '#EEF0F5', '#C9CCDA', '#1A1D3A', '#6B7090'


def checkbox(on):
    if on:
        return f'<span style="color:#2B3990;display:flex;flex-shrink:0">{icon("checksquare", 22)}</span>'
    return '<span style="display:block;width:22px;height:22px;border:2px solid #CDD0DE;border-radius:6px;flex-shrink:0"></span>'


def toggle(on):
    bg = '#2B3990' if on else '#D5D8E4'
    pos = 'inset-inline-end:3px' if on else 'inset-inline-start:3px'
    return (f'<span style="position:relative;width:46px;height:28px;border-radius:14px;background:{bg};flex-shrink:0">'
            f'<span style="position:absolute;top:3px;{pos};width:22px;height:22px;border-radius:11px;background:#fff;box-shadow:0 1px 3px rgba(26,29,58,.2)"></span></span>')


# ── End of session ──

def session_header(title, sub, status='En cours'):
    return f'''<div style="height:76px;background:#1C2566;display:flex;align-items:center;gap:16px;padding:0 32px;color:#fff">
  <span class="btn" style="height:40px;background:rgba(255,255,255,.1);color:#fff;font-size:13px">{icon('arrowleft', 16)}Ma journée</span>
  <div style="flex:1"><div style="font-size:20px;font-weight:800">{title}</div><div style="font-size:13px;opacity:.75;font-weight:600">{sub}</div></div>
  <span class="chip" style="background:rgba(18,163,154,.2);color:#7FE3DA"><span class="dot" style="background:#7FE3DA"></span>{status}</span>
  <span class="btn" style="background:#fff;color:#1A1D3A">{icon('flag', 17)}Terminer la séance</span>
</div>'''


def pupil_tile(initials, name, state):
    colors = {'Présent': ('#E7F6EA', '#B9E3C2', '#237A35'), 'Absent': ('#FDECEC', '#F6C9C9', '#B42525'), 'En retard': ('#FDEEE4', '#F7CDB2', '#B5440A')}
    bg, border, fg = colors[state]
    return (f'<div style="display:flex;align-items:center;gap:12px;padding:12px 14px;background:{bg};border:1px solid {border};border-radius:16px">'
            f'<span class="av" style="width:36px;height:36px;background:#fff;color:{fg};font-size:13px">{initials}</span>'
            f'<span style="flex:1;font-size:15px;font-weight:700">{name}</span><span style="font-size:13px;font-weight:800;color:{fg}">{state}</span></div>')


PUPILS = [('AG', 'Adam Gharbi', 'Présent'), ('AK', 'Amine Kefi', 'Absent'), ('RM', 'Rayen Mansour', 'Présent'),
          ('YB', 'Yasmine Ben Ali', 'Présent'), ('ET', 'Eya Trabelsi', 'Présent'), ('MB', 'Malek Ben Ali', 'Présent')]


def session_screen():
    tiles = ''.join(pupil_tile(*p) for p in PUPILS)
    return f'''{session_header('4ème année · Maths', '10:00 à 11:30 · Présentiel · Salle 2')}
<div style="padding:32px;display:flex;gap:24px;align-items:flex-start">
  <div class="card" style="flex:1.1;display:flex;flex-direction:column;gap:14px">
    <div style="display:flex;align-items:center"><div style="flex:1;font-size:18px;font-weight:800">Présences</div><span class="s13">Touchez un élève pour changer</span></div>
    <div style="display:flex;gap:8px">{chip('5 présents', 'green')}{chip('1 absent', 'red')}{chip('0 en retard', 'orange')}</div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px">{tiles}</div>
  </div>
  <div style="flex:1;display:flex;flex-direction:column;gap:24px">
    <div class="card" style="display:flex;flex-direction:column;gap:12px"><div style="display:flex;align-items:center"><div style="flex:1;font-size:18px;font-weight:800">Contenu du jour</div>{chip('Chapitre · Les fractions', 'indigo')}</div>
      <div style="display:flex;align-items:center;gap:12px;padding:12px;border:1px solid #E6E8F0;border-radius:16px">{badge('filetext', 'red', 40, 12, 20)}<div style="flex:1"><div class="t15">Série 1 : les fractions</div><div class="s13">Page écrite · Série</div></div><span class="btn secondary sm">Ouvrir</span></div></div>
    <div class="card" style="display:flex;flex-direction:column;gap:10px"><div class="cap" style="letter-spacing:1px">NOTE RAPIDE</div><div class="input" style="min-height:70px;align-items:flex-start;padding:12px 14px;font-size:14px;line-height:1.5">Amine absent. Revoir la simplification avec Rayen.</div></div>
  </div>
</div>'''


def doc_choice(on, kind, title, sub):
    ic = {'page': ('filetext', 'red'), 'quiz': ('listchecks', 'violet')}[kind]
    return (f'<div style="display:flex;align-items:center;gap:12px;padding:10px 12px;border:1px solid {"#C9CEEC" if on else "#E6E8F0"};border-radius:14px;background:{"#F4F5FC" if on else "#fff"}">'
            f'{checkbox(on)}{badge(ic[0], ic[1], 32, 10, 16)}<div style="flex:1"><div style="font-size:14px;font-weight:700">{title}</div><div class="s13" style="font-size:12px">{sub}</div></div></div>')


def end_panel():
    return f'''<div class="scrim"></div>
<div class="panel" style="width:560px">
  <div class="panel-h">{badge('flag', 'green', 44, 14, 20)}<div style="flex:1"><div style="font-size:20px;font-weight:800">Fin de séance</div>
    <div class="s13">4ème année · Maths · mardi 6 octobre · 10:00 à 11:30</div></div>{icon('x', 22, color='#6B7090')}</div>
  <div class="panel-b" style="gap:22px">
    <div class="field"><label>Présences</label>
      <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">{chip('5 présents', 'green')}{chip('1 absent · Amine Kefi', 'red')}{chip('0 en retard', 'orange')}
      <span style="flex:1"></span><span style="font-size:13px;font-weight:700;color:#2B3990">Modifier</span></div></div>
    <div class="field"><label>Ce qui a été vu</label>
      <div class="input" style="justify-content:space-between"><span style="display:flex;align-items:center;gap:10px">{icon('book', 18, color='#2B3990')}Les fractions</span>{icon('chevdown', 18, color='#6B7090')}</div>
      <div style="display:flex;flex-direction:column;gap:8px">
        {doc_choice(True, 'page', 'Série 1 : les fractions', 'Contenu du jour')}
        {doc_choice(False, 'quiz', 'Quiz : les fractions', 'Les fractions')}
        {doc_choice(False, 'page', 'Cours : comparer deux fractions', 'Les fractions')}
      </div>
      <div class="input" style="font-size:14px">Exercices 1 à 4, la comparaison au même dénominateur.</div>
      <div class="hint">Les élèves et les parents le voient dans Cours : « Vu en classe le mardi 6 octobre ».</div></div>
    <div class="field"><label>Note de séance <span class="s13" style="font-weight:500">· visible par vous uniquement</span></label>
      <div class="input" style="min-height:64px;align-items:flex-start;padding:12px 14px;font-size:14px;line-height:1.5">Amine absent. Revoir la simplification avec Rayen.</div></div>
    <div class="field"><label>Ensuite</label>
      <div style="display:flex;align-items:center;gap:14px;padding:14px;border:1px solid #C9CEEC;border-radius:16px;background:#F4F5FC">{toggle(True)}
        <div style="flex:1"><div class="t15">Donner un devoir</div><div class="s13">S'ouvre avec ce groupe et Les fractions, après « Terminer ».</div></div></div>
      <div style="display:flex;align-items:center;gap:12px;padding:12px 14px;border-radius:14px;background:#F6F7FB">{icon('repeat', 18, color='#2B3990')}
        <div style="flex:1;font-size:13px;color:#4A4F72">Prochaine séance déjà au planning : <b style="color:#1A1D3A">jeudi 8 octobre · 10:00</b></div></div></div>
  </div>
  <div class="panel-f"><span class="btn ghost">Retour</span><span class="btn primary">{icon('check', 17, 2.4)}Terminer la séance</span></div>
</div>'''


def end_desktop():
    body = f'<div style="min-height:1000px;background:#F6F7FB">{session_screen()}</div>{end_panel()}'
    return page('Fin de séance', body, height=1000)


def teacher_phone_end():
    return phone(f'''
    <div style="display:flex;align-items:center;gap:10px">{badge('flag', 'green', 40, 12, 18)}<div style="flex:1"><div style="font-size:20px;font-weight:800">Fin de séance</div><div class="s13">Sara Ben Amor · Lecture</div></div>{icon('x', 22, color='#6B7090')}</div>
    <div style="display:flex;gap:8px">{chip('Présente', 'green')}<span style="flex:1"></span><span style="font-size:13px;font-weight:700;color:#2B3990">Modifier</span></div>
    <div class="field"><label>Ce qui a été vu</label>
      <div class="input" style="justify-content:space-between;min-height:44px"><span style="display:flex;align-items:center;gap:8px;font-size:14px">{icon('book', 16, color='#2B3990')}Lire un conte</span>{icon('chevdown', 16, color='#6B7090')}</div>
      {doc_choice(True, 'page', 'Le loup et l\'agneau', 'Contenu du jour')}</div>
    <div class="field"><label>Note de séance</label><div class="input" style="min-height:52px;font-size:14px">Lecture plus fluide. Travailler les liaisons.</div></div>
    <div class="field"><label>Prochaine séance</label>
      <div style="display:flex;gap:8px"><div class="input" style="flex:1.3;min-height:44px;font-size:14px">{icon('calendar', 16, color='#2B3990')}Jeudi 8 octobre</div><div class="input" style="flex:1;min-height:44px;font-size:14px;direction:ltr">16:00 à 17:00</div></div>
      <div class="hint">Un cours particulier sans série : proposée le même jour la semaine suivante, à la même heure.</div></div>
    <div style="display:flex;align-items:center;gap:12px;padding:12px;border:1px solid #E6E8F0;border-radius:16px">{toggle(False)}<div class="t15" style="flex:1">Donner un devoir</div></div>
    <span class="btn primary" style="justify-content:center;height:48px">{icon('check', 17, 2.4)}Terminer la séance</span>
    ''', TEACHER_NAV, 'fr', 0)


def teacher_phone_next():
    return phone(f'''
    <div style="margin:-18px -18px 0;padding:16px 18px;background:#1C2566;color:#fff;display:flex;align-items:center;gap:10px">{icon('arrowleft', 20)}<div style="flex:1"><div style="font-size:17px;font-weight:800">4ème année · Maths</div><div style="font-size:12px;opacity:.75;font-weight:600">Jeudi 8 octobre · 10:00 à 11:30</div></div></div>
    <div style="padding:16px;border-radius:20px;background:#FFF8E8;border:1px solid #FBE3B0;display:flex;flex-direction:column;gap:8px">
      <div class="cap" style="color:#9A6300;letter-spacing:1px">DERNIÈRE SÉANCE · MARDI</div>
      <div style="display:flex;gap:8px;flex-wrap:wrap">{chip('Vu · Les fractions', 'indigo')}{chip('1 absent', 'red')}</div>
      <div style="font-size:14px;color:#1A1D3A;line-height:1.5"><b>Série 1 : les fractions</b> · Exercices 1 à 4, la comparaison au même dénominateur.</div>
      <div style="font-size:14px;color:#4A4F72;line-height:1.5">Amine absent. Revoir la simplification avec Rayen.</div>
      <div class="s13" style="font-weight:600">Devoir donné : Série 2 : les fractions, pour jeudi</div>
    </div>
    <div style="display:flex;align-items:center"><div style="flex:1;font-size:16px;font-weight:800">Présences</div><span class="s13">6 élèves</span></div>
    <div style="display:flex;flex-direction:column;gap:8px">{pupil_tile('AG', 'Adam Gharbi', 'Présent')}{pupil_tile('AK', 'Amine Kefi', 'Présent')}{pupil_tile('RM', 'Rayen Mansour', 'En retard')}</div>
    ''', TEACHER_NAV, 'fr', 0)


PUPIL_NAV_AR = [('house', 'الرئيسية'), ('book', 'الدروس'), ('clipboard', 'الفروض'), ('calendar', 'الجدول'), ('chart', 'النتائج')]
PARENT_NAV_AR = [('dashboard', 'نظرة عامة'), ('book', 'الدروس'), ('clipboard', 'الفروض'), ('calendar', 'الجدول'), ('bell', 'الإشعارات')]


def pupil_cours_ar():
    def doc(kind, title, sub):
        ic = {'page': ('filetext', 'red'), 'quiz': ('listchecks', 'violet')}[kind]
        return (f'<div style="display:flex;align-items:center;gap:12px;padding:12px;background:#fff;border:1px solid #E6E8F0;border-radius:16px">'
                f'{badge(ic[0], ic[1], 36, 10, 18)}<div style="flex:1"><div class="t15"><bdi>{title}</bdi></div><div class="s13">{sub}</div></div>{icon("chevleft", 18, color="#6B7090")}</div>')
    return phone(f'''
    <div style="font-size:24px;font-weight:700">الدروس</div>
    <div style="display:flex;gap:8px"><span class="chip" style="background:#1C2566;color:#fff;padding:8px 14px;font-size:13px">رياضيات</span><span class="chip" style="background:#fff;border:1px solid #E6E8F0;color:#4A4F72;padding:8px 14px;font-size:13px">قراءة</span></div>
    <div style="display:flex;flex-direction:column;gap:10px;padding:16px;background:#fff;border:1.5px solid #C9CEEC;border-radius:20px">
      <div style="display:flex;align-items:center;gap:10px"><div style="flex:1;font-size:17px;font-weight:700"><bdi>Les fractions</bdi></div>{chip('شوهد في القسم', 'green')}</div>
      <div class="s13" style="font-weight:600">الثلاثاء 6 أكتوبر · <bdi>Exercices 1 à 4, la comparaison au même dénominateur.</bdi></div>
      {doc('page', 'Série 1 : les fractions', 'شوهد في القسم')}
      {doc('quiz', 'Quiz : les fractions', 'فرض حتى الخميس')}
    </div>
    <div style="display:flex;flex-direction:column;gap:10px;padding:16px;background:#fff;border:1px solid #E6E8F0;border-radius:20px">
      <div style="display:flex;align-items:center;gap:10px"><div style="flex:1;font-size:17px;font-weight:700"><bdi>La multiplication</bdi></div>{chip('شوهد في القسم', 'green')}</div>
      <div class="s13" style="font-weight:600">الخميس 1 أكتوبر</div>
      {doc('page', 'Série 3 : la multiplication', 'شوهد في القسم')}
    </div>
    ''', PUPIL_NAV_AR, 'ar', 1)


END_NOTES = [
    ('Après « Terminer la séance »', 'Un seul panneau, prérempli : les présences (modifiables), ce qui a été vu, la note de séance. Rien n\'est obligatoire : « Terminer » suffit, comme aujourd\'hui (spec 03).'),
    ('Ce qui a été vu', 'Un chapitre de la matière et du niveau du groupe (le chapitre du « Contenu du jour » d\'abord), les documents utilisés (ceux du jour cochés), et une précision libre.'),
    ('Pour les familles', 'Dans Cours, le chapitre porte « Vu en classe » avec la date et la précision ; les documents vus aussi. La note de séance reste privée.'),
    ('Pour la prochaine fois', 'La séance suivante du groupe s\'ouvre sur « Dernière séance » : ce qui a été vu, les absences, la note, le devoir donné. Le chapitre compte dans « Chapitres vus » des résultats.'),
    ('Ensuite', '« Donner un devoir » ouvre le formulaire habituel avec le groupe et le chapitre. « Prochaine séance » n\'apparaît que pour une séance sans série (un cours particulier ponctuel) ; sinon une ligne dit quand est la prochaine.'),
]


def board(columns, title, sub, notes, height):
    def column(label, content):
        return f'<div style="display:flex;flex-direction:column;gap:14px;align-items:center"><div class="cap" style="font-size:13px">{label}</div>{content}</div>'
    items = ''.join(
        f'<div style="display:flex;gap:12px"><span style="width:26px;height:26px;border-radius:13px;background:#2B3990;color:#fff;font-size:13px;font-weight:800;display:flex;align-items:center;justify-content:center;flex-shrink:0">{i}</span>'
        f'<div><div style="font-size:15px;font-weight:800">{t}</div><div style="font-size:14px;color:#4A4F72;line-height:1.5;margin-top:2px">{x}</div></div></div>'
        for i, (t, x) in enumerate(notes, 1))
    cols = ''.join(column(label, content) for label, content in columns)
    body = f'''<div style="padding:48px;display:flex;flex-direction:column;gap:40px;background:#EEF0FA">
  <div style="display:flex;gap:40px;justify-content:center;align-items:flex-start">{cols}</div>
  <div style="width:1250px;align-self:center;background:#fff;border:1px solid #E6E8F0;border-radius:24px;padding:26px;display:flex;flex-direction:column;gap:16px">
    <div style="font-size:22px;font-weight:800">{title}</div>
    <div style="font-size:14px;color:#6B7090;line-height:1.5">{sub}</div>{items}
  </div>
</div>'''
    return page(title, body, width=1440, height=height)


def end_phones():
    return board([('ENSEIGNANTE · COURS PARTICULIER', teacher_phone_end()), ('ENSEIGNANTE · SÉANCE SUIVANTE', teacher_phone_next()),
                  ('ÉLÈVE · ARABE · الدروس', pupil_cours_ar())],
                 'Version 4 : la fin de séance', 'Spec 03 (fin de séance). Données inventées, mardi 6 octobre.', END_NOTES, 1560)


# ── Progress charts ──

MONTHS_FR = ['sept.', 'oct.', 'nov.', 'déc.', 'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin']
MONTHS_AR = ['سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر', 'جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان']
# (subject, colour, marker, [(month position 0..9.99, grade /20)])
SERIES = [
    ('Mathématiques', INDIGO, 'circle', [(0.6, 12), (1.3, 13.5), (1.8, 15.5), (2.5, 14), (3.4, 16), (4.6, 15), (5.2, 17), (6.4, 16.5)]),
    ('Lecture', TURQUOISE, 'square', [(0.9, 11), (1.9, 12), (2.8, 10.5), (4.2, 13), (5.4, 14), (6.2, 13.5)]),
    ('Éveil', ORANGE, 'diamond', [(1.5, 15), (3.2, 14), (4.9, 16), (6.0, 17)]),
]
SHORT = {'Mathématiques': 'Maths', 'Lecture': 'Lecture', 'Éveil': 'Éveil'}
MONTHLY = [(100, 100), (80, 95), (100, 90), (75, 100), (100, 100), (100, 95), (67, 100)]  # (devoirs rendus %, présence %)


def marker(shape, x, y, color, r=4.5):
    ring = 'stroke="#fff" stroke-width="2"'
    if shape == 'square':
        return f'<rect x="{x - r}" y="{y - r}" width="{2 * r}" height="{2 * r}" rx="1.5" fill="{color}" {ring}/>'
    if shape == 'diamond':
        d = r * 1.35
        return f'<path d="M{x} {y - d}L{x + d} {y}L{x} {y + d}L{x - d} {y}Z" fill="{color}" {ring}/>'
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color}" {ring}/>'


def legend_key(shape, color):
    return f'<svg width="22" height="12" style="flex-shrink:0"><path d="M1 6H21" stroke="{color}" stroke-width="2"/>{marker(shape, 11, 6, color, 4)}</svg>'


def line_chart(w, h, months, rtl=False, compact=False, hover=True):
    left, right, top, bottom = (34, 74, 12, 28) if not compact else (26, 12, 10, 24)
    pw, ph = w - left - right, h - top - bottom
    shown = 7 if compact else 10

    def X(m):
        v = left + pw * m / shown
        return w - v if rtl else v

    def Y(g):
        return top + ph * (1 - g / 20)
    out = []
    for g in (0, 5, 10, 15, 20):
        out.append(f'<line x1="{left if not rtl else right}" x2="{w - right if not rtl else w - left}" y1="{Y(g)}" y2="{Y(g)}" stroke="{GRID if g else AXIS}" stroke-width="1"/>')
        lx = left - 8 if not rtl else w - left + 8
        out.append(f'<text x="{lx}" y="{Y(g) + 4}" font-size="11" fill="{MUTED}" text-anchor="{"end" if not rtl else "start"}" style="direction:ltr">{g}</text>')
    for i in range(shown):
        mx = X(i + 0.5)
        past = i <= 6
        out.append(f'<text x="{mx}" y="{h - 6}" font-size="11" fill="{MUTED if past else "#B4B8CC"}" text-anchor="middle">{months[i]}</text>')
    for name, color, shape, pts in SERIES:
        d = ' '.join(f'{"M" if k == 0 else "L"}{X(m):.1f} {Y(g):.1f}' for k, (m, g) in enumerate(pts))
        out.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>')
        out.extend(marker(shape, X(m), Y(g), color, 3.5 if compact else 4.5) for m, g in pts)
    if not compact:
        # Direct labels at the end of each line, pushed apart so they never touch (14 px at least).
        ends = sorted(((Y(pts[-1][1]), X(pts[-1][0]), SHORT[name], pts[-1][1]) for name, _, _, pts in SERIES))
        placed = []
        for y, x, label, g in ends:
            y = max(y, placed[-1] + 15) if placed else y
            placed.append(y)
            far = max(X(p[-1][0]) for *_, p in SERIES)
            lx = far + (14 if not rtl else -14)
            out.append(f'<line x1="{x}" x2="{lx - (4 if not rtl else -4)}" y1="{Y(g)}" y2="{y}" stroke="{AXIS}" stroke-width="1"/>')
            out.append(f'<text x="{lx}" y="{y + 4}" font-size="12" font-weight="700" fill="{INK}" text-anchor="{"start" if not rtl else "end"}">{label} {str(g).replace(".", ",")}</text>')
    if hover:
        m, g = SERIES[0][3][6]
        hx, hy = X(m), Y(g)
        out.append(f'<line x1="{hx}" x2="{hx}" y1="{top}" y2="{top + ph}" stroke="{AXIS}" stroke-width="1" stroke-dasharray="3 3"/>')
        out.append(f'<circle cx="{hx}" cy="{hy}" r="7" fill="none" stroke="{INDIGO}" stroke-width="2"/>')
    return f'<svg width="{w}" height="{h}" style="display:block;overflow:visible">{"".join(out)}</svg>'


def bar_chart(w, h, months, rtl=False, compact=False):
    left, right, top, bottom = (40, 12, 12, 28) if not compact else (32, 6, 10, 24)
    pw, ph = w - left - right, h - top - bottom
    n = len(MONTHLY)
    slot = pw / n
    bw = min(16 if not compact else 10, (slot - 14) / 2)

    def X(v):
        return w - v if rtl else v

    def Y(p):
        return top + ph * (1 - p / 100)
    out = []
    for p in (0, 50, 100):
        out.append(f'<line x1="{left if not rtl else right}" x2="{w - right if not rtl else w - left}" y1="{Y(p)}" y2="{Y(p)}" stroke="{GRID if p else AXIS}" stroke-width="1"/>')
        lx = left - 8 if not rtl else w - left + 8
        out.append(f'<text x="{lx}" y="{Y(p) + 4}" font-size="11" fill="{MUTED}" text-anchor="{"end" if not rtl else "start"}" style="direction:ltr">{p} %</text>')
    for i, (hw, at) in enumerate(MONTHLY):
        cx = left + slot * (i + 0.5)
        for k, (val, color) in enumerate([(hw, INDIGO), (at, TURQUOISE)]):
            x0 = cx - bw - 1 if k == 0 else cx + 1  # 2px gap between the pair
            x = X(x0 + bw) if rtl else X(x0)
            y = Y(val)
            r = 4 if not compact else 3
            out.append(f'<path d="M{x} {Y(0)}V{y + r}Q{x} {y} {x + r} {y}H{x + bw - r}Q{x + bw} {y} {x + bw} {y + r}V{Y(0)}Z" fill="{color}"/>')
        out.append(f'<text x="{X(cx)}" y="{h - 6}" font-size="11" fill="{MUTED}" text-anchor="middle">{months[i]}</text>')
    # one selective label: the month that needs a look
    cx = left + slot * 6.5
    out.append(f'<text x="{X(cx - bw / 2 - 1)}" y="{Y(67) - 6}" font-size="11" font-weight="700" fill="{INK}" text-anchor="middle" style="direction:ltr">67 %</text>')
    return f'<svg width="{w}" height="{h}" style="display:block;overflow:visible">{"".join(out)}</svg>'


def tooltip(x, y, rtl=False):
    side = f'{"right" if rtl else "left"}:{x}px'
    return (f'<div style="position:absolute;top:{y}px;{side};width:210px;padding:10px 12px;background:#fff;border:1px solid #E6E8F0;border-radius:12px;'
            f'box-shadow:0 8px 24px rgba(28,37,102,.14);display:flex;flex-direction:column;gap:4px">'
            f'<div class="cap" style="display:flex;align-items:center;gap:6px">{legend_key("circle", INDIGO)}Mathématiques</div>'
            f'<div style="font-size:14px;font-weight:700">Quiz : la division</div>'
            f'<div style="display:flex;align-items:baseline;gap:6px"><span style="font-size:18px;font-weight:800;direction:ltr">17/20</span><span class="s13">vendredi 6 février</span></div></div>')


def legend(items):
    return '<div style="display:flex;gap:16px;flex-wrap:wrap">' + ''.join(
        f'<span style="display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600;color:#4A4F72">{legend_key(s, c)}{n}</span>' for n, c, s in items) + '</div>'


def bars_legend(ar=False):
    hw, at = ('الفروض المسلّمة', 'الحضور') if ar else ('Devoirs rendus', 'Présence')
    return ('<div style="display:flex;gap:16px">'
            f'<span style="display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600;color:#4A4F72"><span style="width:12px;height:12px;border-radius:3px;background:{INDIGO}"></span>{hw}</span>'
            f'<span style="display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600;color:#4A4F72"><span style="width:12px;height:12px;border-radius:3px;background:{TURQUOISE}"></span>{at}</span></div>')


PUPIL_NAV = [('house', 'Accueil'), ('book', 'Cours'), ('clipboard', 'Devoirs'), ('calendar', 'Planning'), ('chart', 'Résultats')]


def family_sidebar():
    items = ''.join(f'<a class="{"on" if label == "Résultats" else ""}">{icon(i)}{label}</a>' for i, label in PUPIL_NAV)
    return f'''<nav class="side">
  <div class="brand"><img src="ng-symbol.png" alt=""><div><span style="font-weight:800;color:#2B3990">NextGeneration</span><br><span style="font-weight:500;color:#12A39A">Class</span></div></div>
  <div class="nav">{items}</div>
  <div class="ucard">{avatar('AG', 'indigo', 40, True)}<div style="flex:1"><div style="font-size:14px;font-weight:700">Adam Gharbi</div><div class="cap" style="font-weight:500">Élève</div></div>{icon('chevdown', 18, color='#6B7090')}</div>
</nav>'''


def subject_card(name, color, avg, trend, hw, att, chapters):
    t = chip('En progrès', 'green') if trend == 'up' else chip('Stable', 'indigo', dot=False)
    return f'''<div class="card" style="padding:20px;display:flex;flex-direction:column;gap:12px">
  <div style="display:flex;align-items:center;gap:8px"><span style="width:10px;height:10px;border-radius:3px;background:{color}"></span><span class="cap" style="letter-spacing:1px;flex:1">{name.upper()}</span>{t}</div>
  <div style="display:flex;align-items:baseline;gap:6px"><span style="font-size:36px;font-weight:800;letter-spacing:-1px;direction:ltr">{avg}</span><span style="font-size:15px;font-weight:700;color:#6B7090">/20</span></div>
  <div style="display:flex;gap:8px"><div style="flex:1;padding:10px 12px;background:#F6F7FB;border-radius:12px"><div class="t15">{hw}</div><div class="s13" style="font-size:12px">devoirs rendus</div></div>
    <div style="flex:1;padding:10px 12px;background:#F6F7FB;border-radius:12px"><div class="t15">{att}</div><div class="s13" style="font-size:12px">présence</div></div></div>
  <div class="s13" style="line-height:1.5"><b style="color:#1A1D3A">Chapitres vus</b> · {chapters}</div>
</div>'''


def progress_desktop():
    keys = [(n, c, s) for n, c, s, _ in SERIES]
    content = f'''<div class="top" style="justify-content:flex-end"><span class="btn secondary" style="height:40px;padding:0 14px;font-size:13px;color:#4A4F72">FR · ع</span>
  <span class="btn secondary" style="width:44px;padding:0;justify-content:center;color:#4A4F72">{icon('bell')}</span></div>
<div class="page" style="max-width:1176px">
  <div><h1 class="ptitle" style="font-size:32px">Mes résultats</h1><div style="font-size:15px;color:#4A4F72;margin-top:6px">Tes notes et ton travail, matière par matière. Année 2026-2027.</div></div>
  <div class="card" style="display:flex;flex-direction:column;gap:14px;position:relative">
    <div style="display:flex;align-items:center;gap:12px"><div style="flex:1"><div style="font-size:18px;font-weight:800">Mes notes au fil de l'année</div><div class="s13">Chaque point est une note, ramenée sur 20.</div></div>
      <span class="btn secondary sm">{icon('table', 16)}Voir en tableau</span></div>
    {legend(keys)}
    {line_chart(1110, 280, MONTHS_FR)}
    {tooltip(330, 250)}
  </div>
  <div style="display:grid;grid-template-columns:1.25fr 1fr;gap:24px">
    <div class="card" style="display:flex;flex-direction:column;gap:14px">
      <div><div style="font-size:18px;font-weight:800">Chaque mois</div><div class="s13">Les devoirs rendus et la présence, toutes matières.</div></div>
      {bars_legend()}
      {bar_chart(570, 200, MONTHS_FR)}
    </div>
    <div style="display:flex;flex-direction:column;gap:16px">
      {subject_card('Mathématiques', INDIGO, '15,30', 'up', '12 sur 13', '96 %', 'Les nombres jusqu\'à 100 000, La multiplication, Les fractions, La division')}
      {subject_card('Lecture', TURQUOISE, '12,40', 'up', '9 sur 10', '96 %', 'Lire un conte, Le dialogue')}
    </div>
  </div>
</div>'''
    body = f'<div class="app" style="min-height:1100px">{family_sidebar()}<div class="main" style="background:#F6F7FB">{content}</div></div>'
    return page('Progression', body, height=1100)


def results_phone_fr():
    keys = [(n, c, s) for n, c, s, _ in SERIES]
    return phone(f'''
    <div style="font-size:24px;font-weight:800">Mes résultats</div>
    <div style="padding:16px;background:#fff;border:1px solid #E6E8F0;border-radius:20px;display:flex;flex-direction:column;gap:10px">
      <div style="display:flex;align-items:center"><div style="flex:1;font-size:16px;font-weight:800">Mes notes au fil de l'année</div>{icon('table', 18, color='#2B3990')}</div>
      {legend(keys)}
      {line_chart(322, 190, MONTHS_FR[:7] + [''] * 3, compact=True, hover=False)}
      <div class="s13">Touche un point pour voir la note.</div>
    </div>
    <div style="padding:16px;background:#fff;border:1px solid #E6E8F0;border-radius:20px;display:flex;flex-direction:column;gap:10px">
      <div style="font-size:16px;font-weight:800">Chaque mois</div>{bars_legend()}
      {bar_chart(322, 150, MONTHS_FR, compact=True)}
    </div>
    ''', PUPIL_NAV, 'fr', 4)


def results_phone_ar():
    keys = [('رياضيات', INDIGO, 'circle'), ('قراءة', TURQUOISE, 'square'), ('إيقاظ', ORANGE, 'diamond')]
    return phone(f'''
    <div><div class="s13" style="font-weight:600">نتائج آدم</div><div style="font-size:24px;font-weight:700">النتائج</div></div>
    <div style="padding:16px;background:#fff;border:1px solid #E6E8F0;border-radius:20px;display:flex;flex-direction:column;gap:10px">
      <div style="display:flex;align-items:center"><div style="flex:1;font-size:16px;font-weight:700">الأعداد على مدار السنة</div>{icon('table', 18, color='#2B3990')}</div>
      {legend(keys)}
      {line_chart(322, 190, MONTHS_AR[:7] + [''] * 3, rtl=True, compact=True, hover=False)}
    </div>
    <div style="padding:16px;background:#fff;border:1px solid #E6E8F0;border-radius:20px;display:flex;flex-direction:column;gap:10px">
      <div style="font-size:16px;font-weight:700">كل شهر</div>{bars_legend(ar=True)}
      {bar_chart(322, 150, MONTHS_AR, rtl=True, compact=True)}
    </div>
    ''', PARENT_NAV_AR, 'ar', 0)


def table_phone():
    rows = [('Quiz : la division', 'Maths', 'ven. 6 févr.', '17/20'), ('Dictée 4', 'Lecture', 'mar. 3 févr.', '14/20'),
            ('Série 5 : la division', 'Maths', 'jeu. 22 janv.', '7,5/10'), ('Les volcans', 'Éveil', 'lun. 19 janv.', '16/20'),
            ('Lecture à voix haute', 'Lecture', 'ven. 9 janv.', '13/20')]
    trs = ''.join(f'<div style="display:flex;align-items:center;gap:10px;padding:10px 0;border-top:1px solid #F0F1F6"><div style="flex:1"><div style="font-size:14px;font-weight:700">{t}</div><div class="s13" style="font-size:12px">{s} · {d}</div></div><span style="font-size:15px;font-weight:800;direction:ltr">{g}</span></div>' for t, s, d, g in rows)
    return phone(f'''
    <div style="display:flex;align-items:center;gap:10px">{icon('arrowleft', 20)}<div style="flex:1;font-size:20px;font-weight:800">Mes notes en tableau</div></div>
    <div class="tabs" style="align-self:flex-start"><span class="on">Notes</span><span>Chaque mois</span></div>
    <div style="padding:6px 16px 10px;background:#fff;border:1px solid #E6E8F0;border-radius:20px">{trs}</div>
    <div class="s13">Les mêmes chiffres que la courbe, pour les lire un par un.</div>
    ''', PUPIL_NAV, 'fr', 4)


CHART_NOTES = [
    ('Mes notes au fil de l\'année', 'Une courbe par matière, chaque point une note ramenée sur 20, de septembre à juin. Chaque matière garde sa couleur, une forme de point à elle et son nom en bout de courbe : on la reconnaît sans les couleurs.'),
    ('Toucher un point', 'La note, son devoir ou son évaluation, et la date. Sur ordinateur au survol, sur téléphone au toucher. « Voir en tableau » donne les mêmes chiffres en liste.'),
    ('Chaque mois', 'Deux barres par mois : les devoirs rendus et la présence, en pourcentage. Une seule valeur écrite : celle qui demande un coup d\'œil.'),
    ('Qui voit quoi', 'L\'élève et ses parents dans Résultats, l\'enseignante dans la fiche de l\'élève (le même panneau). Jamais de moyenne de classe ni de classement (spec 07).'),
    ('Peu de notes', 'Avec une seule note la courbe est remplacée par « La courbe apparaît dès la deuxième note. » Les « Chapitres vus » viennent des fins de séance.'),
]


def progress_phones():
    return board([('ÉLÈVE · RÉSULTATS', results_phone_fr()), ('PARENT · ARABE · النتائج', results_phone_ar()), ('ÉLÈVE · VOIR EN TABLEAU', table_phone())],
                 'Version 4 : la progression', 'Spec 07 (graphiques). Données inventées, lundi 16 mars 2027.', CHART_NOTES, 1560)


if __name__ == '__main__':
    (OUT / 'FinDeSeance.html').write_text(end_desktop())
    (OUT / 'FinDeSeancePhone.html').write_text(end_phones())
    (OUT / 'Progression.html').write_text(progress_desktop())
    (OUT / 'ProgressionPhone.html').write_text(progress_phones())
    print('FinDeSeance, FinDeSeancePhone, Progression, ProgressionPhone')
