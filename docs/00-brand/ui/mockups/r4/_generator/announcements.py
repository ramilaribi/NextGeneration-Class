"""Release 4: announcements (spec 08), one-way messages from the teacher to a group, a pupil or the parents."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'r2' / '_generator'))

from contents import square  # noqa: E402  (also puts the R1 generator on the path)

import common  # noqa: E402
from common import ACCENTS, avatar, chip, icon, page, sidebar, topbar  # noqa: E402
from planning import phone  # noqa: E402
from scan import frame  # noqa: E402
from teacher_notifications import TEACHER_NAV  # noqa: E402

OUT = Path(__file__).resolve().parents[1]

common.ICONS.update({
    'send': '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
    'eye': '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
    'checksquare': '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="m8 12 3 3 5-6"/>',
    'user': '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
    'book': '<path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"/>',
    'chart': '<path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/>',
    'dashboard': '<rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/><rect width="7" height="9" x="14" y="12" rx="1"/><rect width="7" height="5" x="3" y="16" rx="1"/>',
})

AUDIENCE = {'both': ('Élèves et parents', 'indigo'), 'parents': ('Parents', 'turquoise'), 'pupils': ('Élèves', 'amber')}


def megaphone(size=44, accent='indigo'):
    _, soft, on = ACCENTS[accent]
    return (f'<span class="badge" style="width:{size}px;height:{size}px;border-radius:14px;background:{soft};color:{on}">'
            f'{icon("megaphone", int(size * 0.45))}</span>')


def readbar(read, total):
    pct = int(100 * read / total)
    return f'''<div style="display:flex;align-items:center;gap:10px;min-width:170px">
  <div style="flex:1;height:6px;border-radius:3px;background:#E6E8F0;overflow:hidden"><div style="width:{pct}%;height:100%;background:#12A39A"></div></div>
  <span class="cap" style="color:#1A1D3A;direction:ltr">{read} / {total} lus</span></div>'''


def target(code, name):
    return f'<span style="display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600">{square(code, 18)}{name}</span>'


def person(initials, name):
    return f'<span style="display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600">{avatar(initials, "violet", 20)}{name}</span>'


def announcement(title, text, targets, audience, when, read, total, new=False):
    label, accent = AUDIENCE[audience]
    return f'''<div class="card" style="padding:20px;display:flex;gap:16px;{"border-color:#C9CEEC" if new else ""}">
  {megaphone(44, 'indigo')}
  <div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:8px">
    <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap"><span class="t15" style="font-size:16px;font-weight:800">{title}</span>{chip(label, accent)}</div>
    <div style="font-size:14px;line-height:1.55;color:#4A4F72">{text}</div>
    <div style="display:flex;align-items:center;gap:14px;flex-wrap:wrap">{''.join(targets)}<span class="cap" style="font-weight:600">· {when}</span></div>
  </div>
  <div style="display:flex;flex-direction:column;align-items:flex-end;gap:12px">{icon('more', 20, color='#6B7090')}{readbar(read, total)}</div>
</div>'''


LIST = [
    ('Sortie au musée jeudi', 'Jeudi 15 octobre, sortie au musée du Bardo. Départ de l\'école à 9 h, retour à 13 h. Pensez au goûter et à une casquette.',
     [target('4A', '4ème année · Maths'), target('4L', '4ème année · Lecture')], 'parents', 'Aujourd\'hui à 09:12', 9, 14, True),
    ('Pas de séance lundi', 'Lundi 12 octobre est férié : pas de séance. On se retrouve mardi aux heures habituelles.',
     [target('4A', '4ème année · Maths'), target('4L', '4ème année · Lecture'), target('6E', '6ème année · Éveil')], 'both', 'Hier à 18:40', 31, 34),
    ('Bravo pour le quiz !', 'Toute la classe a bien travaillé sur le quiz des fractions. Continuez comme ça, on corrige ensemble mardi.',
     [target('4A', '4ème année · Maths')], 'pupils', 'Mardi 6 octobre', 6, 6),
    ('Le cahier de lecture', 'Sara, pense à apporter ton cahier de lecture à la prochaine séance.',
     [person('SB', 'Sara Ben Amor')], 'both', 'Lundi 5 octobre', 2, 2),
]


def list_page():
    rows = ''.join(announcement(*a) for a in LIST)
    return f'''<div class="page">
  <div style="display:flex;align-items:flex-end;gap:16px">
    <div style="flex:1"><h1 class="ptitle">Annonces</h1>
      <div style="font-size:15px;color:#4A4F72;margin-top:6px">Un message à un groupe, à un élève ou à leurs parents. Il reste 7 jours sur leur accueil.</div></div>
    <span class="btn primary">{icon('plus', 18, 2.4)}Nouvelle annonce</span>
  </div>
  <div class="tabs"><span class="on">Toutes <span class="count" style="background:#2B3990;color:#fff">4</span></span><span>{square('4A', 18)}4ème année · Maths</span><span>{square('4L', 18)}4ème année · Lecture</span><span>{square('6E', 18)}6ème année · Éveil</span></div>
  <div style="display:flex;flex-direction:column;gap:12px">{rows}</div>
</div>'''


def checkbox(on):
    if on:
        return f'<span style="color:#2B3990;display:flex">{icon("checksquare", 22)}</span>'
    return '<span style="display:block;width:22px;height:22px;border:2px solid #CDD0DE;border-radius:6px;flex-shrink:0"></span>'


def new_panel():
    groups = ''.join(
        f'<div style="display:flex;align-items:center;gap:12px;padding:10px 12px;border:1px solid {"#C9CEEC" if on else "#E6E8F0"};border-radius:14px;background:{"#F4F5FC" if on else "#fff"}">'
        f'{checkbox(on)}{square(code, 24)}<span style="flex:1;font-size:14px;font-weight:600">{name}</span><span class="cap" style="font-weight:500">{n} élèves</span></div>'
        for code, name, n, on in [('4A', '4ème année · Maths', 6, True), ('4L', '4ème année · Lecture', 5, True), ('6E', '6ème année · Éveil', 4, False)])
    preview = f'''<div style="border:1px dashed #C9CEEC;border-radius:18px;padding:14px;background:#F6F7FB;display:flex;flex-direction:column;gap:8px">
  <div class="cap" style="text-transform:uppercase;letter-spacing:1px">Ce que voient les parents</div>
  <div style="display:flex;gap:12px;padding:14px;background:#fff;border:1px solid #E6E8F0;border-radius:16px">
    {megaphone(36)}<div style="flex:1"><div class="t15">Sortie au musée jeudi</div>
    <div style="font-size:13px;color:#4A4F72;line-height:1.5;margin-top:2px">Jeudi 15 octobre, sortie au musée du Bardo. Départ de l'école à 9 h…</div>
    <div class="cap" style="font-weight:600;margin-top:6px">Mme Haddad · à l'instant</div></div></div></div>'''
    return f'''<div class="scrim"></div>
<div class="panel" style="width:540px">
  <div class="panel-h">{megaphone(44)}<div style="flex:1"><div style="font-size:20px;font-weight:800">Nouvelle annonce</div>
    <div class="s13">Elle arrive dans leurs notifications et sur leur accueil.</div></div>{icon('x', 22, color='#6B7090')}</div>
  <div class="panel-b" style="gap:18px">
    <div class="field"><label>Pour qui</label>
      <div class="seg"><span class="on">{icon('users', 16)}Des groupes</span><span>{icon('user', 16)}Un élève</span></div>
      <div style="display:flex;flex-direction:column;gap:8px">{groups}</div></div>
    <div class="field"><label>Qui la reçoit</label>
      <div class="seg"><span>Élèves</span><span class="on">Parents</span><span>Élèves et parents</span></div>
      <div class="hint">Une annonce aux parents n'est pas visible par les élèves.</div></div>
    <div class="field"><label>Titre</label><div class="input focus">Sortie au musée jeudi</div></div>
    <div class="field"><label>Message</label><div class="input" style="min-height:88px;align-items:flex-start;padding:12px 14px;line-height:1.5;font-size:14px">Jeudi 15 octobre, sortie au musée du Bardo. Départ de l'école à 9 h, retour à 13 h. Pensez au goûter et à une casquette.</div></div>
    {preview}
  </div>
  <div class="panel-f"><span class="btn ghost">Annuler</span><span class="btn primary">{icon('send', 17)}Envoyer à 11 familles</span></div>
</div>'''


def desktop():
    body = f'''<div class="app" style="min-height:900px">{sidebar('Annonces')}<div class="main">{topbar()}{list_page()}</div></div>'''
    return page('Annonces', body)


def desktop_new():
    body = f'''<div class="app" style="min-height:1000px">{sidebar('Annonces')}<div class="main">{topbar()}{list_page()}</div></div>{new_panel()}'''
    return page('Nouvelle annonce', body, height=1000)


# ── Phones and the families' side ──

PARENT_NAV = [('dashboard', 'Aperçu'), ('book', 'Cours'), ('clipboard', 'Devoirs'), ('calendar', 'Planning'), ('bell', 'Notifications')]
PUPIL_NAV_AR = [('house', 'الرئيسية'), ('book', 'الدروس'), ('clipboard', 'الفروض'), ('calendar', 'الجدول'), ('chart', 'النتائج')]


def teacher_phone():
    def row(title, audience, when, read, total, targets):
        label, accent = AUDIENCE[audience]
        return (f'<div style="display:flex;flex-direction:column;gap:8px;padding:14px;background:#fff;border:1px solid #E6E8F0;border-radius:18px">'
                f'<div style="display:flex;align-items:center;gap:8px">{megaphone(32)}<span class="t15" style="flex:1">{title}</span></div>'
                f'<div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center">{chip(label, accent)}{targets}</div>'
                f'<div style="display:flex;align-items:center;gap:10px"><span class="cap" style="font-weight:600;flex:1">{when}</span>{readbar(read, total)}</div></div>')
    return phone(f'''
    <div style="display:flex;align-items:center;gap:10px"><div style="flex:1;font-size:24px;font-weight:800">Annonces</div>
      <span class="btn primary sm" style="height:40px">{icon('plus', 16, 2.4)}Nouvelle</span></div>
    {row('Sortie au musée jeudi', 'parents', 'Aujourd\'hui à 09:12', 9, 14, square('4A', 18) + square('4L', 18))}
    {row('Pas de séance lundi', 'both', 'Hier à 18:40', 31, 34, square('4A', 18) + square('4L', 18) + square('6E', 18))}
    {row('Bravo pour le quiz !', 'pupils', 'Mardi 6 octobre', 6, 6, square('4A', 18))}
    ''', TEACHER_NAV, 'fr', 4)


def parent_home():
    return phone(f'''
    <div style="display:flex;align-items:center;gap:12px"><div style="flex:1"><div class="s13" style="font-weight:600">Aperçu</div><div style="font-size:22px;font-weight:800">Bonjour Mouna</div></div>{avatar('MG', 'turquoise', 40, True)}</div>
    <div style="display:flex;gap:8px"><span class="chip" style="background:#1A1D3A;color:#fff;padding:8px 14px;font-size:13px">Adam · 4ème année</span></div>
    <div style="display:flex;flex-direction:column;gap:10px;padding:16px;background:#fff;border:1.5px solid #C9CEEC;border-radius:20px">
      <div style="display:flex;align-items:center;gap:10px">{megaphone(36)}<div style="flex:1"><div class="cap" style="text-transform:uppercase;letter-spacing:1px">Annonce · Mme Haddad</div><div class="t15" style="font-size:16px">Sortie au musée jeudi</div></div>
        <span style="width:9px;height:9px;border-radius:5px;background:#2B3990"></span></div>
      <div style="font-size:14px;color:#4A4F72;line-height:1.55">Jeudi 15 octobre, sortie au musée du Bardo. Départ de l'école à 9 h, retour à 13 h. Pensez au goûter et à une casquette.</div>
      <div class="cap" style="font-weight:600">Aujourd'hui à 09:12 · 4ème année · Maths</div>
    </div>
    <div style="display:flex;gap:10px">
      <div style="flex:1;padding:14px;background:#fff;border:1px solid #E6E8F0;border-radius:18px"><div class="cap">MOYENNE</div><div style="font-size:22px;font-weight:800;margin-top:4px;direction:ltr;text-align:start">15,50 /20</div></div>
      <div style="flex:1;padding:14px;background:#fff;border:1px solid #E6E8F0;border-radius:18px"><div class="cap">PRÉSENCE</div><div style="font-size:22px;font-weight:800;margin-top:4px">95 %</div></div>
    </div>
    <div style="padding:16px;background:#fff;border:1px solid #E6E8F0;border-radius:18px"><div class="cap">PROCHAINE SÉANCE</div><div class="t15" style="margin-top:6px">Mardi 13 octobre · 15:00</div><div class="s13">4ème année · Maths · Salle 2</div></div>
    ''', PARENT_NAV, 'fr', 0)


def pupil_ar():
    return phone(f'''
    <div style="display:flex;align-items:center;gap:10px"><div style="flex:1"><div class="s13" style="font-weight:600">الأحد 11 أكتوبر</div><div style="font-size:24px;font-weight:700">مرحبًا آدم</div></div>
      <span class="btn secondary" style="width:44px;height:44px;padding:0;justify-content:center;position:relative">{icon('bell', 20)}<span style="position:absolute;top:-6px;inset-inline-end:-6px;min-width:20px;height:20px;border-radius:10px;background:#FFB020;border:2px solid #fff;font-size:10px;font-weight:800;display:flex;align-items:center;justify-content:center">1</span></span></div>
    <div class="cap" style="font-size:13px;color:#1A1D3A">جديد</div>
    <div style="display:flex;gap:12px;padding:16px;background:#fff;border:1.5px solid #C9CEEC;border-radius:20px">
      {megaphone(40)}<div style="flex:1;display:flex;flex-direction:column;gap:4px"><div class="cap">إعلان · <bdi>Mme Haddad</bdi></div>
      <div class="t15" style="font-size:16px"><bdi>Bravo pour le quiz !</bdi></div>
      <div style="font-size:14px;color:#4A4F72;line-height:1.6"><bdi>Toute la classe a bien travaillé sur le quiz des fractions. Continuez comme ça, on corrige ensemble mardi.</bdi></div>
      <div class="cap" style="font-weight:600">الثلاثاء 6 أكتوبر</div></div></div>
    <div style="padding:18px;border-radius:22px;background:#0B7C75;color:#fff"><div style="font-size:13px;font-weight:700;opacity:.8">الحصة القادمة</div><div style="font-size:30px;font-weight:700;direction:ltr;text-align:end">15:00</div><div style="font-size:15px;font-weight:600"><bdi>4ème année · Maths</bdi> · القاعة 2</div></div>
    ''', PUPIL_NAV_AR, 'ar', 0)


NOTES = [
    ('Pour qui', 'Un ou plusieurs groupes, ou un seul élève. Puis qui la reçoit : les élèves, les parents, ou les deux. Une annonce aux parents n\'est jamais visible par les élèves (spec 08).'),
    ('Où elle arrive', 'Dans les notifications de chacun (la cloche des élèves, l\'onglet Notifications des parents) et en haut de leur accueil pendant 7 jours, puis seulement dans les notifications.'),
    ('Lu par', 'Chaque annonce montre combien l\'ont lue (« 9 / 14 lus »). La toucher montre qui ne l\'a pas encore lue, pour relancer de vive voix.'),
    ('Sans réponse', 'Une annonce est à sens unique (question Q9) : les familles gardent leurs moyens habituels pour répondre. Modifier ou supprimer est possible tant que personne ne l\'a lue.'),
    ('Pas encore', 'Ni notification sur le téléphone ni e-mail (décision du 9 octobre : pas de push pour l\'instant). Le menu « Annonces » revient une fois ces écrans approuvés.'),
]


def phone_board():
    def column(label, content):
        return f'<div style="display:flex;flex-direction:column;gap:14px;align-items:center"><div class="cap" style="font-size:13px">{label}</div>{content}</div>'

    notes = ''.join(
        f'<div style="display:flex;gap:12px"><span style="width:26px;height:26px;border-radius:13px;background:#2B3990;color:#fff;font-size:13px;font-weight:800;display:flex;align-items:center;justify-content:center;flex-shrink:0">{i}</span>'
        f'<div><div style="font-size:15px;font-weight:800">{title}</div><div style="font-size:14px;color:#4A4F72;line-height:1.5;margin-top:2px">{text}</div></div></div>'
        for i, (title, text) in enumerate(NOTES, 1))
    body = f'''<div style="padding:48px;display:flex;flex-direction:column;gap:40px;background:#EEF0FA">
  <div style="display:flex;gap:40px;justify-content:center;align-items:flex-start">
    {column('ENSEIGNANTE · ANNONCES', teacher_phone())}
    {column('PARENT · APERÇU', parent_home())}
    {column('ÉLÈVE · ARABE · الرئيسية', pupil_ar())}
  </div>
  <div style="width:1250px;align-self:center;background:#fff;border:1px solid #E6E8F0;border-radius:24px;padding:26px;display:flex;flex-direction:column;gap:16px">
    <div style="font-size:22px;font-weight:800">Version 4 : les annonces</div>
    <div style="font-size:14px;color:#6B7090;line-height:1.5">Spec 08 (annonces), sans notifications push. Données inventées, dimanche 11 octobre.</div>
    {notes}
  </div>
</div>'''
    return page('Annonces sur téléphone', body, width=1440, height=1500)


if __name__ == '__main__':
    (OUT / 'Annonces.html').write_text(desktop())
    (OUT / 'NouvelleAnnonce.html').write_text(desktop_new())
    (OUT / 'AnnoncesPhone.html').write_text(phone_board())
    print('Annonces, NouvelleAnnonce, AnnoncesPhone')
