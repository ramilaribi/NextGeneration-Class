"""Release 3, step 4: PDF worksheets ("Fiches", spec 05): a page or a quiz printed in a pupil and a teacher version."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'r2' / '_generator'))

from contents import square  # noqa: E402  (also puts the R1 generator on the path)

import common  # noqa: E402
from common import ACCENTS, chip, icon, page, sidebar, topbar  # noqa: E402
from scan import frame  # noqa: E402

OUT = Path(__file__).resolve().parents[1]

common.ICONS.update({
    'printer': '<path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><path d="M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6"/><rect x="6" y="14" width="12" height="8" rx="1"/>',
    'download': '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>',
    'checksquare': '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="m8 12 3 3 5-6"/>',
    'listchecks': '<path d="m3 17 2 2 4-4M3 7l2 2 4-4M13 6h8M13 12h8M13 18h8"/>',
    'filepen': '<path d="M12.5 22H18a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v9.5"/><path d="M14 2v4a2 2 0 0 0 2 2h4M13.38 12.62a2.12 2.12 0 0 1 3 3L11 21l-4 1 1-4Z"/>',
    'share': '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.59 13.51 6.83 3.98M15.41 6.51l-6.82 3.98"/>',
})

GREEN = '#237A35'


def frac(a, b, size=1.0, color='inherit'):
    return (f'<span style="display:inline-flex;flex-direction:column;align-items:center;vertical-align:middle;line-height:1;margin:0 2px;'
            f'font-size:{0.82 * size}em;color:{color};font-family:Times New Roman,serif;font-weight:700">'
            f'<span style="padding:0 2px">{a}</span><span style="border-top:1.2px solid currentColor;padding:1px 2px 0">{b}</span></span>')


def box(checked=False, teacher=False):
    if checked and teacher:
        return f'<span style="display:inline-flex;width:14px;height:14px;border-radius:7px;background:{GREEN};color:#fff;align-items:center;justify-content:center;font-size:10px;font-weight:800">✓</span>'
    return '<span style="display:inline-block;width:14px;height:14px;border-radius:7px;border:1.4px solid #4A4F72"></span>'


def dots(width=160):
    return f'<span style="display:inline-block;width:{width}px;border-bottom:1.4px dotted #4A4F72;height:1em;vertical-align:baseline"></span>'


def answer(text):
    return f'<span style="color:{GREEN};font-weight:800;border-bottom:1.4px dotted {GREEN};padding:0 6px">{text}</span>'


def sheet(teacher=False, scale=1.0, width=595):
    """An A4 page (595 x 842 points): the header, the name line, then the quiz's questions."""
    t = teacher
    q = lambda n, pts, body: (f'<div style="display:flex;flex-direction:column;gap:7px;padding:10px 0;border-top:1px solid #EEF0F6">'
                              f'<div style="display:flex;gap:6px;align-items:baseline"><b style="color:#2B3990">{n}.</b>'
                              f'<div style="flex:1">{body[0]}</div><span style="font-size:10px;color:#6B7090;font-weight:700">{pts}</span></div>{body[1]}</div>')
    choices = ''.join(f'<span style="display:inline-flex;align-items:center;gap:6px;margin-inline-end:22px">{box(ok, t)}{frac(a, b, 1.1, GREEN if ok and t else "inherit")}</span>'
                      for a, b, ok in [(2, 4, True), (2, 3, False), (3, 4, False)])
    tf = (f'<span style="display:inline-flex;align-items:center;gap:6px;margin-inline-end:22px">{box(True, t)}<span style="{f"color:{GREEN};font-weight:800" if t else ""}">Vrai</span></span>'
          f'<span style="display:inline-flex;align-items:center;gap:6px">{box(False, t)}Faux</span>')
    lines = ''.join('<div style="border-bottom:1.2px dotted #9AA0B8;height:20px"></div>' for _ in range(3))
    pad = '<div style="padding-inline-start:16px">'
    explain = (f'<div style="padding-inline-start:16px;font-size:10px;color:{GREEN}">Explication : '
               f'{frac(3, 5)} = {frac(21, 35)} et {frac(4, 7)} = {frac(20, 35)}</div>') if t else ''
    model = (f'<div style="padding-inline-start:16px;font-size:10px;color:{GREEN};font-weight:600">'
             'À corriger : on les met au même dénominateur, puis on compare les numérateurs.</div>') if t else ''
    short = answer('1 (ou 4/4)') if t else dots(120)
    gap1 = answer('numérateur') if t else dots(90)
    gap2 = answer('dénominateur') if t else dots(90)
    mark = "<b style='color:#237A35'>/ 10</b>" if t else dots(40) + ' / 10'
    corrige = ' · Corrigé' if t else ''
    q1 = q(1, '2 pts', (f'Quelle fraction est égale à {frac(1, 2)} ?', f'{pad}{choices}</div>'))
    q2 = q(2, '1 pt', (f'{frac(3, 5)} &gt; {frac(4, 7)}', f'{pad}{tf}</div>{explain}'))
    q3 = q(3, '2 pts', (f'Calcule {frac(3, 4)} + {frac(1, 4)}.', f'{pad}Réponse : {short}</div>'))
    q4 = q(4, '2 pts', (f'Dans la fraction {frac(3, 4)}, 3 est le {gap1} et 4 le {gap2}.', ''))
    q5 = q(5, '3 pts', ('Explique comment tu compares deux fractions.',
                        f'<div style="padding-inline-start:16px;display:flex;flex-direction:column;gap:2px">{lines}</div>{model}'))
    body = f'''
<div style="display:flex;align-items:center;gap:10px;padding-bottom:8px;border-bottom:2px solid #2B3990">
  <img src="ng-symbol.png" style="height:22px" alt="">
  <div style="flex:1;text-align:center"><div style="font-size:15px;font-weight:800">Quiz : les fractions{corrige}</div>
    <div style="font-size:10px;color:#6B7090;font-weight:600">Mathématiques · 4ème année · Les fractions</div></div>
  <div style="text-align:end;font-size:10px;color:#6B7090;font-weight:600;line-height:1.4">Mme Haddad<br>12 octobre 2026</div>
</div>
<div style="display:flex;gap:18px;font-size:11px;color:#4A4F72;font-weight:600;padding:8px 0 4px">
  <span style="flex:1">Nom et prénom : {dots(170)}</span><span>Note : {mark}</span></div>
{q1}
{q2}
{q3}
{q4}
{q5}
<div style="margin-top:auto;font-size:9px;color:#9AA0B8;text-align:center">NextGeneration Class · page 1 / 1</div>'''
    return (f'<div style="width:{width}px;height:{int(width * 1.414)}px;background:#fff;padding:{int(36 * width / 595)}px {int(40 * width / 595)}px;'
            f'box-shadow:0 10px 30px rgba(28,37,102,.14);border-radius:3px;display:flex;flex-direction:column;font-size:{12.5 * width / 595:.1f}px;'
            f'color:#1A1D3A;font-family:\'Plus Jakarta Sans\',sans-serif;transform-origin:top left">{body}</div>')


def checkbox(on, label):
    mark = (f'<span style="color:#2B3990;display:flex">{icon("checksquare", 21)}</span>' if on
            else '<span style="display:block;width:21px;height:21px;border:2px solid #CDD0DE;border-radius:6px;flex-shrink:0"></span>')
    return f'<div style="display:flex;align-items:center;gap:10px;font-size:14px;font-weight:600">{mark}{label}</div>'


def settings():
    return f'''<div class="card" style="width:380px;flex-shrink:0;display:flex;flex-direction:column;gap:18px;padding:22px">
  <div style="font-size:18px;font-weight:800">Réglages de la fiche</div>
  <div class="field"><label>À partir de</label>
    <div style="display:flex;align-items:center;gap:10px;padding:10px 12px;border:1px solid #E6E8F0;border-radius:14px">
      <span class="badge" style="width:36px;height:36px;border-radius:10px;background:#F1ECFD;color:#5B34D6">{icon('listchecks', 18)}</span>
      <div style="flex:1"><div class="t15">Quiz : les fractions</div><div class="s13">5 questions · 10 points</div></div><a style="font-size:13px;font-weight:700">Changer</a></div>
    <div class="hint">Une page écrite dans l'application ou un quiz. Une série importée en PDF s'imprime déjà telle quelle.</div></div>
  <div class="field"><label>Version</label>
    <div class="seg"><span class="on">Élève</span><span>Enseignante</span></div>
    <div class="hint">La version enseignante ajoute les bonnes réponses, en vert.</div></div>
  <div class="field"><label>Titre</label><div class="input">Quiz : les fractions</div>
    <div style="display:flex;gap:8px;flex-wrap:wrap"><span class="chip" style="background:#EEF0FA;color:#2B3990">Fiche de révision : …</span><span class="chip" style="background:#EEF0FA;color:#2B3990">Contrôle : …</span></div></div>
  <div class="field"><label>En-tête</label>
    {checkbox(True, 'Matière, niveau et chapitre')}{checkbox(True, 'Date : 12 octobre 2026')}{checkbox(True, 'Votre nom : Mme Haddad')}{checkbox(True, 'Ligne « Nom et prénom » et la note')}</div>
  <div style="display:flex;align-items:center;gap:12px;padding:12px 14px;background:#F6F7FB;border-radius:14px">
    <span style="width:46px;height:28px;border-radius:14px;background:#2B3990;padding:3px;display:flex;justify-content:flex-end;flex-shrink:0"><span style="width:22px;height:22px;border-radius:11px;background:#fff"></span></span>
    <div><div style="font-size:14px;font-weight:700">L'enregistrer dans Contenus</div><div class="s13">Comme une fiche (PDF), à partager ou donner en devoir</div></div></div>
</div>'''


def screen():
    content = f'''<div class="page" style="gap:18px">
  <a style="font-size:14px;font-weight:700;display:flex;align-items:center;gap:6px">{icon('arrowleft', 18)}Contenus</a>
  <div style="display:flex;align-items:center;gap:16px">
    <span class="badge" style="width:52px;height:52px;border-radius:16px;background:#FDECEC;color:#B42525">{icon('printer', 24)}</span>
    <div style="flex:1"><h1 class="ptitle" style="font-size:30px">Fiche : Quiz : les fractions</h1><div class="s13" style="margin-top:4px">A4 · 1 page · version élève</div></div>
    <span class="btn secondary">{icon('download', 18)}Télécharger le PDF</span><span class="btn primary">{icon('printer', 18)}Imprimer</span>
  </div>
  <div style="display:flex;gap:24px;align-items:flex-start">
    {settings()}
    <div style="flex:1;display:flex;justify-content:center;padding:24px;background:#E9EBF3;border-radius:22px">{sheet(False, width=520)}</div>
  </div>
</div>'''
    body = f'''<div class="app" style="min-height:1100px">{sidebar('Contenus')}<div class="main">{topbar()}{content}</div></div>'''
    return page('Fiche PDF', body, height=1100)


NOTES = [
    ('Depuis un document', 'Dans Contenus, le menu « … » d\'une page écrite dans l\'application ou d\'un quiz propose « Imprimer une fiche ». La fiche se règle à gauche, l\'aperçu A4 se met à jour à droite.'),
    ('Deux versions', '« Élève » : les questions, des cases et des pointillés pour répondre, la ligne « Nom et prénom ». « Enseignante » : la même page avec les bonnes réponses en vert, les explications et ce qui attend votre correction. Seules les réponses changent (critère de la spec 05).'),
    ('Une page écrite', 'Une série écrite dans l\'application s\'imprime avec ses formules, tableaux et images ; sa version enseignante ajoute son Corrigé à la suite.'),
    ('Ensuite', 'Télécharger le PDF, l\'imprimer, ou l\'enregistrer dans Contenus comme une fiche (PDF) à partager ou donner en devoir. Les formules restent nettes à l\'impression.'),
    ('Sur téléphone', 'L\'aperçu prend l\'écran ; « Partager » ouvre le partage du téléphone (WhatsApp, e-mail, impression).'),
]


def versions_board():
    notes = ''.join(
        f'<div style="display:flex;gap:12px"><span style="width:26px;height:26px;border-radius:13px;background:#2B3990;color:#fff;font-size:13px;font-weight:800;display:flex;align-items:center;justify-content:center;flex-shrink:0">{i}</span>'
        f'<div><div style="font-size:15px;font-weight:800">{title}</div><div style="font-size:14px;color:#4A4F72;line-height:1.5;margin-top:2px">{text}</div></div></div>'
        for i, (title, text) in enumerate(NOTES, 1))
    phone_body = f'''<div style="display:flex;align-items:center;gap:10px;padding:14px 16px;background:#fff;border-bottom:1px solid #E6E8F0">
    <span class="btn secondary" style="width:42px;height:42px;padding:0;justify-content:center">{icon('arrowleft', 20)}</span>
    <div style="flex:1"><div style="font-size:16px;font-weight:800">Fiche · version élève</div><div class="s13">Quiz : les fractions</div></div></div>
  <div style="flex:1;background:#E9EBF3;padding:14px;display:flex;justify-content:center;overflow:hidden">{sheet(False, width=350)}</div>
  <div style="display:flex;gap:10px;padding:12px 16px;background:#fff;border-top:1px solid #E6E8F0">
    <span class="btn secondary" style="flex:1;justify-content:center">{icon('share', 17)}Partager</span><span class="btn primary" style="flex:1;justify-content:center">{icon('printer', 17)}Imprimer</span></div>'''

    def column(label, content):
        return f'<div style="display:flex;flex-direction:column;gap:14px;align-items:center"><div class="cap" style="font-size:13px">{label}</div>{content}</div>'

    body = f'''<div style="padding:48px;display:flex;flex-direction:column;gap:40px;background:#EEF0FA">
  <div style="display:flex;gap:36px;justify-content:center;align-items:flex-start">
    {column('VERSION ÉLÈVE', sheet(False, width=440))}
    {column('VERSION ENSEIGNANTE', sheet(True, width=440))}
    {column('TÉLÉPHONE', frame(phone_body))}
  </div>
  <div style="width:1300px;align-self:center;background:#fff;border:1px solid #E6E8F0;border-radius:24px;padding:26px;display:flex;flex-direction:column;gap:16px">
    <div style="font-size:22px;font-weight:800">Version 3, étape 4 : les fiches PDF</div>
    <div style="font-size:14px;color:#6B7090;line-height:1.5">Spec 05 (fiches), deux versions de la même sélection, A4 portrait. Données inventées, lundi 12 octobre.</div>
    {notes}
  </div>
</div>'''
    return page('Fiches PDF, deux versions', body, width=1520, height=1500)


if __name__ == '__main__':
    (OUT / 'Fiche.html').write_text(screen())
    (OUT / 'FicheVersions.html').write_text(versions_board())
    print('Fiche, FicheVersions')
