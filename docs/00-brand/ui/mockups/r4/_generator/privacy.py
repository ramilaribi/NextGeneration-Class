"""Before going live: the privacy notice and the parents' agreement (children's data, loi organique n° 2004-63)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'r2' / '_generator'))

from contents import square  # noqa: E402,F401  (also puts the R1 generator on the path)

import common  # noqa: E402
from common import avatar, badge, chip, icon, page  # noqa: E402
from planning import phone  # noqa: E402
from teacher_notifications import TEACHER_NAV  # noqa: E402

OUT = Path(__file__).resolve().parents[1]

common.ICONS.update({
    'shield': '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
    'database': '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/>',
    'eye': '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
    'hourglass': '<path d="M5 22h14M5 2h14M17 22v-4.17a2 2 0 0 0-.59-1.42L12 12l-4.41 4.41A2 2 0 0 0 7 17.83V22M7 2v4.17a2 2 0 0 0 .59 1.42L12 12l4.41-4.41A2 2 0 0 0 17 6.17V2"/>',
    'hand': '<path d="M18 11V6a2 2 0 0 0-4 0v5M14 10V4a2 2 0 0 0-4 0v6M10 10.5V6a2 2 0 0 0-4 0v8"/><path d="M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/>',
    'server': '<rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><path d="M6 6h.01M6 18h.01"/>',
    'filecheck': '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4M9 15l2 2 4-4"/>',
    'checksquare': '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="m8 12 3 3 5-6"/>',
    'logout': '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>',
})

MASCOTS = '''<div style="position:absolute;bottom:0;inset-inline-start:56px;display:flex;align-items:flex-end;gap:24px">
  <div style="width:96px;height:200px;border-radius:48px 48px 0 0;background:#2B3990"></div>
  <div style="width:200px;height:100px;border-radius:100px 100px 0 0;background:#12A39A"></div>
  <div style="width:104px;height:150px;border-radius:52px 52px 0 0;background:#FFB020"></div>
  <div style="width:84px;height:170px;border-radius:42px 42px 0 0;background:#7048E8"></div>
</div>'''


def welcome_side():
    return f'''<div style="width:806px;flex-shrink:0;background:#EEF0FA;position:relative;padding:48px 56px;display:flex;flex-direction:column;gap:28px;overflow:hidden">
  <div class="brand" style="padding:0"><img src="ng-symbol.png" alt="" style="height:40px"><div style="font-size:22px"><span style="font-weight:800;color:#2B3990">NextGeneration</span> <span style="font-weight:500;color:#12A39A">Class</span></div></div>
  <div style="font-size:50px;font-weight:800;letter-spacing:-1.5px;line-height:1.1;margin-top:24px">Enseigner, suivre,<br>progresser.</div>
  <div style="font-size:17px;color:#4A4F72;line-height:1.5;max-width:500px">L'espace privé de votre enseignante, pour ses élèves et leurs parents.</div>
  {MASCOTS}
</div>'''


POINTS_FR = [
    ('database', 'indigo', 'Ce qui est gardé', 'Le nom d\'Adam, son niveau, ses présences, ses devoirs et ses notes, les mots de l\'enseignante ; votre nom et votre téléphone.'),
    ('eye', 'turquoise', 'Qui le voit', 'Mme Haddad, Adam et vous. Jamais les autres familles. Jamais de publicité, rien n\'est vendu.'),
    ('hourglass', 'amber', 'Combien de temps', 'Cette année scolaire et la suivante, puis tout est effacé.'),
    ('hand', 'violet', 'Vos droits', 'Voir, corriger ou faire effacer ces informations : demandez-le à Mme Haddad.'),
]


def checkbox(on):
    if on:
        return f'<span style="color:#2B3990;display:flex;flex-shrink:0">{icon("checksquare", 24)}</span>'
    return '<span style="display:block;width:24px;height:24px;border:2px solid #CDD0DE;border-radius:6px;flex-shrink:0"></span>'


def point(ic, accent, title, text, size=40, compact=False):
    return (f'<div style="display:flex;gap:14px;align-items:flex-start">{badge(ic, accent, size, 12, 19 if not compact else 17)}'
            f'<div style="flex:1"><div class="t15" style="{"font-size:14px" if compact else ""}">{title}</div>'
            f'<div style="font-size:{13 if compact else 14}px;color:#4A4F72;line-height:1.5;margin-top:2px">{text}</div></div></div>')


def agreement_desktop():
    points = ''.join(point(*p) for p in POINTS_FR)
    form = f'''<div style="flex:1;background:#fff;position:relative;display:flex;flex-direction:column">
  <div style="display:flex;justify-content:flex-end;padding:32px 40px"><div class="seg" style="width:auto;border-radius:999px;padding:4px"><span class="on" style="padding:0 16px;border-radius:999px">Français</span><span style="padding:0 16px">العربية</span></div></div>
  <div style="width:460px;align-self:center;display:flex;flex-direction:column;gap:18px;margin-top:-4px">
    <div class="cap" style="color:#0B8A82;letter-spacing:1.4px">AVANT DE COMMENCER</div>
    <div style="font-size:34px;font-weight:800;letter-spacing:-1px;line-height:1.15">Les informations d'Adam</div>
    <div style="font-size:15px;color:#4A4F72;line-height:1.5">Mme Haddad garde quelques informations pour suivre Adam. Voici l'essentiel, en quatre points.</div>
    <div style="display:flex;flex-direction:column;gap:16px;padding:20px;border:1px solid #E6E8F0;border-radius:20px">{points}</div>
    <div style="font-size:14px;font-weight:700;color:#2B3990;display:flex;align-items:center;gap:8px">{icon('shield', 17)}Lire tout le texte</div>
    <div style="display:flex;gap:12px;align-items:flex-start;padding:14px;border:1.5px solid #2B3990;border-radius:16px;background:#F4F5FC">{checkbox(True)}
      <div style="font-size:14px;font-weight:600;line-height:1.5">J'accepte que Mme Haddad garde ces informations pour suivre Adam.</div></div>
    <span class="btn primary" style="height:54px;justify-content:center;font-size:16px;box-shadow:0 10px 24px rgba(43,57,144,.25)">Continuer{icon('arrowleft', 18, style='transform:scaleX(-1)')}</span>
    <div style="display:flex;align-items:center;gap:8px;justify-content:center;font-size:13px;color:#6B7090">Pas d'accord ? Parlez-en à Mme Haddad. <span style="font-weight:700;color:#4A4F72;display:inline-flex;gap:6px;align-items:center">{icon('logout', 15)}Se déconnecter</span></div>
  </div>
</div>'''
    body = f'<div style="display:flex;min-height:980px">{welcome_side()}{form}</div>'
    return page('Accord des parents', body, height=980)


SECTIONS_FR = [
    ('shield', 'indigo', 'Qui est responsable', 'Mme Ines Haddad, l\'enseignante de votre enfant. NextGeneration Class est l\'outil qu\'elle utilise pour ses séances, ses devoirs et le suivi de ses élèves.'),
    ('database', 'indigo', 'Ce qui est gardé', 'Pour l\'enfant : nom, prénom, niveau et groupes ; présences ; devoirs rendus (photos et fichiers) ; notes et résultats ; les commentaires de l\'enseignante. Pour vous : nom, prénom, téléphone, et le lien avec votre enfant. Pour se connecter : un identifiant et un mot de passe chiffré.'),
    ('filecheck', 'turquoise', 'Pourquoi', 'Organiser les séances, donner et corriger les devoirs, suivre les progrès et vous tenir informé. Rien d\'autre : pas de publicité, pas de revente, pas d\'envoi à d\'autres services.'),
    ('eye', 'turquoise', 'Qui le voit', 'L\'enseignante voit ses élèves. Votre enfant et vous voyez les informations de votre enfant. Les autres familles ne voient jamais rien de vous. La personne qui gère la plateforme voit seulement les comptes des enseignantes, jamais le contenu de leur espace.'),
    ('server', 'amber', 'Où', 'Sur un serveur loué en France (OVHcloud), avec une sauvegarde chaque nuit. Les échanges avec l\'application sont chiffrés.'),
    ('hourglass', 'amber', 'Combien de temps', 'Pendant l\'année scolaire et l\'année suivante. Ensuite, les informations d\'un élève qui a quitté l\'enseignante sont effacées. Vous pouvez demander l\'effacement plus tôt.'),
    ('hand', 'violet', 'Vos droits', 'Vous pouvez voir les informations gardées, les faire corriger, ou demander qu\'elles soient effacées : il suffit de le demander à l\'enseignante. Ces droits viennent de la loi organique n° 2004-63 du 27 juillet 2004 sur la protection des données personnelles.'),
]


def privacy_desktop():
    sections = ''.join(
        f'<div style="display:flex;gap:18px;padding:22px 0;{"border-top:1px solid #F0F1F6" if i else ""}">{badge(ic, ac, 44, 14, 20)}'
        f'<div style="flex:1"><div style="font-size:18px;font-weight:800">{t}</div><div style="font-size:15px;color:#4A4F72;line-height:1.65;margin-top:6px">{x}</div></div></div>'
        for i, (ic, ac, t, x) in enumerate(SECTIONS_FR))
    body = f'''<div style="min-height:1400px;background:#F6F7FB">
  <div style="height:76px;background:#fff;border-bottom:1px solid #E6E8F0;display:flex;align-items:center;gap:14px;padding:0 40px">
    <div class="brand" style="padding:0"><img src="ng-symbol.png" alt="" style="height:32px"><div style="font-size:17px"><span style="font-weight:800;color:#2B3990">NextGeneration</span> <span style="font-weight:500;color:#12A39A">Class</span></div></div>
    <div style="flex:1"></div><span class="btn secondary" style="height:40px;font-size:13px;color:#4A4F72">FR · ع</span><span class="btn ghost">{icon('arrowleft', 16)}Retour</span></div>
  <div style="width:820px;margin:0 auto;padding:44px 0;display:flex;flex-direction:column;gap:10px">
    <div class="cap" style="color:#0B8A82;letter-spacing:1.4px">CONFIDENTIALITÉ</div>
    <h1 class="ptitle">Vos informations et celles de votre enfant</h1>
    <div style="font-size:16px;color:#4A4F72;line-height:1.6;margin:6px 0 14px">Ce que l'enseignante garde, pourquoi, qui le voit et combien de temps. En mots simples.</div>
    <div class="card" style="padding:8px 30px">{sections}</div>
    <div class="s13" style="margin-top:8px">Dernière mise à jour : 14 novembre 2026 · Une question : demandez à l'enseignante de votre enfant.</div>
  </div>
</div>'''
    return page('Confidentialité', body, height=1400)


# ── Phones ──

PARENT_NAV_AR = [('dashboard', 'نظرة عامة'), ('book', 'الدروس'), ('clipboard', 'الفروض'), ('calendar', 'الجدول'), ('bell', 'الإشعارات')]

POINTS_AR = [
    ('database', 'indigo', 'ما يُحفظ', 'اسم آدم ومستواه وحضوره وفروضه وأعداده وملاحظات المعلمة؛ اسمك ورقم هاتفك.'),
    ('eye', 'turquoise', 'من يراه', 'السيدة حداد وآدم وأنت. لا تراه العائلات الأخرى أبدًا. لا إشهار ولا بيع.'),
    ('hourglass', 'amber', 'إلى متى', 'هذه السنة الدراسية والسنة الموالية، ثم يُحذف كل شيء.'),
    ('hand', 'violet', 'حقوقك', 'الاطلاع على هذه المعلومات أو تصحيحها أو طلب حذفها: اطلبه من السيدة حداد.'),
]


def parent_agreement_ar():
    points = ''.join(point(*p, size=34, compact=True) for p in POINTS_AR)
    return f'''<div dir="rtl" style="width:390px;height:844px;background:#fff;border-radius:36px;overflow:hidden;position:relative;font-family:'IBM Plex Sans Arabic',sans-serif;box-shadow:0 20px 60px rgba(28,37,102,.15);border:1px solid #E6E8F0">
  <div style="padding:22px 20px;display:flex;flex-direction:column;gap:14px">
    <div style="display:flex;align-items:center;gap:10px"><img src="ng-symbol.png" alt="" style="height:30px"><div style="flex:1;font-size:15px;font-weight:700;color:#2B3990;direction:ltr;text-align:end">NG Class</div></div>
    <div class="cap" style="color:#0B8A82;font-size:12px">قبل البدء</div>
    <div style="font-size:26px;font-weight:700;line-height:1.3">معلومات آدم</div>
    <div style="font-size:14px;color:#4A4F72;line-height:1.6">تحتفظ السيدة حداد ببعض المعلومات لمتابعة آدم. إليك الأهم في أربع نقاط.</div>
    <div style="display:flex;flex-direction:column;gap:12px;padding:14px;border:1px solid #E6E8F0;border-radius:18px">{points}</div>
    <div style="font-size:14px;font-weight:700;color:#2B3990;display:flex;align-items:center;gap:8px">{icon('shield', 16)}قراءة النص كاملًا</div>
    <div style="display:flex;gap:10px;align-items:flex-start;padding:12px;border:1.5px solid #2B3990;border-radius:14px;background:#F4F5FC">{checkbox(True)}
      <div style="font-size:14px;font-weight:600;line-height:1.6">أوافق على أن تحتفظ السيدة حداد بهذه المعلومات لمتابعة آدم.</div></div>
    <span class="btn primary" style="height:50px;justify-content:center;font-size:15px">متابعة</span>
    <div style="text-align:center;font-size:12.5px;color:#6B7090">غير موافق؟ تحدّث مع السيدة حداد · <b style="color:#4A4F72">تسجيل الخروج</b></div>
  </div>
</div>'''


def teacher_fiche():
    return phone(f'''
    <div style="display:flex;align-items:center;gap:10px">{icon('arrowleft', 20)}<div style="flex:1;font-size:15px;font-weight:700;color:#2B3990">Élèves</div></div>
    <div style="display:flex;align-items:center;gap:12px">{avatar('AG', 'indigo', 52)}<div style="flex:1"><div style="font-size:22px;font-weight:800">Adam Gharbi</div><div class="s13">4ème année · Mouna Gharbi</div></div></div>
    <div style="padding:16px;background:#fff;border:1px solid #E6E8F0;border-radius:20px;display:flex;flex-direction:column;gap:12px">
      <div style="display:flex;align-items:center;gap:10px">{badge('shield', 'green', 36, 10, 18)}<div style="flex:1;font-size:16px;font-weight:800">Accord des parents</div>{chip('Donné', 'green')}</div>
      <div style="font-size:14px;color:#4A4F72;line-height:1.5">Mouna Gharbi, dans l'application, le samedi 14 novembre 2026.</div>
    </div>
    <div class="cap" style="letter-spacing:1px;margin-top:4px">ÉLÈVES · FILTRE « ACCORD EN ATTENTE »</div>
    <div style="padding:16px;background:#fff;border:1.5px solid #F7CDB2;border-radius:20px;display:flex;flex-direction:column;gap:12px">
      <div style="display:flex;align-items:center;gap:10px">{avatar('LB', 'orange', 36)}<div style="flex:1"><div style="font-size:15px;font-weight:800">Lina Bouzid</div><div class="s13">4ème année · Lecture</div></div>{chip('En attente', 'orange')}</div>
      <div style="font-size:14px;color:#4A4F72;line-height:1.5">Samia Bouzid ne s'est pas encore connectée. Si elle a signé la fiche papier :</div>
      <span class="btn secondary" style="justify-content:center">{icon('filecheck', 17)}Accord reçu sur papier</span>
    </div>
    ''', TEACHER_NAV, 'fr', 2)


def privacy_phone_fr():
    rows = ''.join(
        f'<div style="display:flex;gap:12px;padding:12px 0;{"border-top:1px solid #F0F1F6" if i else ""}">{badge(ic, ac, 34, 10, 17)}'
        f'<div style="flex:1"><div style="font-size:15px;font-weight:800">{t}</div><div style="font-size:13px;color:#4A4F72;line-height:1.55;margin-top:2px">{x[:118]}{"…" if len(x) > 118 else ""}</div></div></div>'
        for i, (ic, ac, t, x) in enumerate(SECTIONS_FR[:5]))
    return f'''<div style="width:390px;height:844px;background:#F6F7FB;border-radius:36px;overflow:hidden;position:relative;font-family:'Plus Jakarta Sans',sans-serif;box-shadow:0 20px 60px rgba(28,37,102,.15);border:1px solid #E6E8F0">
  <div style="padding:18px;display:flex;flex-direction:column;gap:10px">
    <div style="display:flex;align-items:center;gap:10px">{icon('arrowleft', 20)}<div style="flex:1"></div><span class="btn secondary" style="height:36px;font-size:12px;padding:0 12px;color:#4A4F72">FR · ع</span></div>
    <div class="cap" style="color:#0B8A82;letter-spacing:1.2px">CONFIDENTIALITÉ</div>
    <div style="font-size:24px;font-weight:800;line-height:1.2;letter-spacing:-.5px">Vos informations et celles de votre enfant</div>
    <div style="padding:4px 16px;background:#fff;border:1px solid #E6E8F0;border-radius:20px">{rows}</div>
  </div>
</div>'''


NOTES = [
    ('Quand', 'À la première connexion d\'un parent, juste après le choix du mot de passe : l\'essentiel en quatre points, une case à cocher, « Continuer ». Une seule fois par parent, pour tous ses enfants (« … pour suivre Adam et Lina »).'),
    ('Sans accord', '« Continuer » reste grisé. Le parent peut se déconnecter et en parler à l\'enseignante : l\'espace reste fermé tant qu\'il n\'a pas accepté. Un élève qui a son propre accès n\'a rien à accepter : ce sont ses parents qui décident.'),
    ('Le texte complet', '« Confidentialité » : en lien sous la connexion (avant même de se connecter) et dans le menu du compte de chacun. En français et en arabe, en mots simples. Texte proposé, à faire valider par l\'enseignante ou un juriste avant la mise en ligne.'),
    ('Côté enseignante', 'Dans la fiche de l\'élève : « Accord des parents », donné (par qui, quand) ou en attente. « Accord reçu sur papier » pour une famille qui ne se connecte pas. Dans Élèves, un filtre « Accord en attente ».'),
    ('Ce qui change', 'L\'accord (qui, quand, comment) est gardé avec le compte. Si le texte change un jour, chaque parent l\'accepte de nouveau à sa connexion suivante.'),
]


def phone_board():
    def column(label, content):
        return f'<div style="display:flex;flex-direction:column;gap:14px;align-items:center"><div class="cap" style="font-size:13px">{label}</div>{content}</div>'
    notes = ''.join(
        f'<div style="display:flex;gap:12px"><span style="width:26px;height:26px;border-radius:13px;background:#2B3990;color:#fff;font-size:13px;font-weight:800;display:flex;align-items:center;justify-content:center;flex-shrink:0">{i}</span>'
        f'<div><div style="font-size:15px;font-weight:800">{t}</div><div style="font-size:14px;color:#4A4F72;line-height:1.5;margin-top:2px">{x}</div></div></div>'
        for i, (t, x) in enumerate(NOTES, 1))
    body = f'''<div style="padding:48px;display:flex;flex-direction:column;gap:40px;background:#EEF0FA">
  <div style="display:flex;gap:40px;justify-content:center;align-items:flex-start">
    {column('PARENT · ARABE · PREMIÈRE CONNEXION', parent_agreement_ar())}
    {column('ENSEIGNANTE · FICHE ÉLÈVE', teacher_fiche())}
    {column('CONFIDENTIALITÉ · TÉLÉPHONE', privacy_phone_fr())}
  </div>
  <div style="width:1250px;align-self:center;background:#fff;border:1px solid #E6E8F0;border-radius:24px;padding:26px;display:flex;flex-direction:column;gap:16px">
    <div style="font-size:22px;font-weight:800">Avant la mise en ligne : l'accord des parents</div>
    <div style="font-size:14px;color:#6B7090;line-height:1.5">Les données d'enfants (loi organique n° 2004-63). Données inventées, samedi 14 novembre 2026.</div>
    {notes}
  </div>
</div>'''
    return page('Confidentialité sur téléphone', body, width=1440, height=1500)


if __name__ == '__main__':
    (OUT / 'AccordParents.html').write_text(agreement_desktop())
    (OUT / 'Confidentialite.html').write_text(privacy_desktop())
    (OUT / 'ConfidentialitePhone.html').write_text(phone_board())
    print('AccordParents, Confidentialite, ConfidentialitePhone')
