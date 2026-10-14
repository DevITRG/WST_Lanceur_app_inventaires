# Changelog — Lanceur d'inventaires (`lanceur_inventaires.au3`)

## [1.0.0.7] — 2026-10-13

### Modifié
- **Le guide s'ouvre dans une fenêtre dédiée, maximisée**, sans barre d'adresse ni barre de favoris : Chrome est lancé en mode application (`--app`, `--start-maximized`), ou Edge à défaut. Sans Chrome ni Edge, le guide s'ouvre dans le navigateur par défaut, comme en 1.0.0.5.
- Si le navigateur ignore la demande de maximisation, par exemple parce qu'il est déjà ouvert, le lanceur attend la fenêtre du guide (5 s au plus) et la maximise lui-même.

### Technique
- Nouvelle fonction `CheminNavigateur()` : chemin de `chrome.exe` ou `msedge.exe`, lu dans la clé de registre `App Paths` (installation pour le poste ou pour l'utilisateur), puis dans les dossiers d'installation habituels.
- Nouvelle variable `$g_sTitreGuide`, qui doit rester identique au `<title>` du guide : elle sert à retrouver la fenêtre pour la maximiser.
- Le guide a désormais le logo RG comme icône, affichée dans la barre des tâches.
- La version 1.0.0.6 (fenêtre en mode application de taille fixe) était une version de test, jamais publiée.

## [1.0.0.5] — 2026-10-13

### Ajouté
- **Lien « Guide d'utilisation »** en bas de la fenêtre, à côté du numéro de version (« v1.0.0.5 · Guide d'utilisation ») : rouge et souligné, rouge foncé au survol, avec une infobulle. Un clic ouvre le guide de formation dans le navigateur par défaut.
- Le guide est cherché dans le sous-dossier **`documentation\guide_inventaires.html`**, à côté du lanceur (avec son dossier `captures`). S'il est absent ou ne s'ouvre pas, un message invite à contacter la Hotline, et l'erreur est écrite dans le log (`[Inv Lanceur]`).

### Technique
- Nouvelle variable `$g_sFichierGuide` (chemin du guide), et nouvelles fonctions `OuvrirGuide()` et `LargeurTexteControle()`. Cette dernière mesure le texte avec la police réelle du libellé, pour que le lien reste collé à la version quelle que soit la mise à l'échelle de l'écran.
- `RG_Charte.au3` est inchangé.

## [1.0.0.4] — 2026-10-09

### Technique
- Le titre de la fenêtre vient désormais de `RG_Charte.au3` (`$RG_TITRE_LANCEUR`) : les inventaires l'utilisent pour ramener le lanceur au premier plan à leur fermeture. Aucun changement visible.

## [1.0.0.3] — 2026-10-08

Recompilation, sans modification du code depuis la 1.0.0.2.

## [1.0.0.2] — 2026-10-08

### Corrigé
- **Logo pixellisé** : l'image 256 px de l'icône est désormais réduite avec un lissage de haute qualité (GDI+, bicubique), au lieu de la réduction sans lissage d'AutoIt. Aucun fichier supplémentaire à livrer.
- **Textes flous sur les écrans mis à l'échelle** (125 %, 150 %) : activation de la mise à l'échelle GDI de Windows (Windows 10 1809 et suivants), qui redessine les textes à la résolution réelle sans changer la mise en page.

### Modifié
- **Rouge officiel Rougegorge** `#EB0026` (au lieu de `#C8102E`), avec ses teintes associées (survol `#B3001D`, roses `#FFD6DD` / `#FDEAED`).
- **Boîtes de dialogue aux couleurs de la charte** (application introuvable, lancement impossible).
- Lien « Quitter » avec effet de survol.

### Technique
- Le lanceur utilise le fichier commun **`RG_Charte.au3`** (couleurs, logo, netteté, dialogues), partagé avec les trois applications. Il doit se trouver à côté du script pour compiler.

## [1.0.0.1] — 2026-10-07

Première version.

### Ajouté
- **Fenêtre unique de lancement** des applications d'inventaire, aux couleurs de Rougegorge Lingerie : bandeau rouge avec le logo, fond ivoire, et une carte par application (nom, description, version installée).
- **Un clic sur une carte lance l'inventaire choisi.** La carte survolée est mise en évidence.
- **Instance unique** (mutex) : relancer le lanceur ramène au premier plan la fenêtre déjà ouverte, au lieu d'en ouvrir une seconde.
- **Inventaire déjà ouvert** : sa fenêtre est ramenée au premier plan, au lieu d'en lancer un second. Deux inventaires simultanés se bloqueraient sur `Transfer.txt`.
- **Application absente** : la carte est grisée et marquée « introuvable ». Un clic affiche « Cette application est introuvable. Merci de contacter la Hotline. ».
- **Journalisation des erreurs** dans le log commun (`[Inv Lanceur]`). Les lancements réussis ne sont pas tracés, car chaque application trace déjà le sien.

### Configuration
- `$g_aApplis` : liste des applications proposées (libellé, description, fichier exe). Ajouter une ligne suffit : la fenêtre s'agrandit automatiquement.
- `$g_sDossierApplis` : dossier des exe, par défaut celui du lanceur.
- Couleurs de la charte : constantes `$COUL_*` en tête du script.
