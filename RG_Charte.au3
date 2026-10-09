#include-once
#include <AutoItConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <MsgBoxConstants.au3>
#include <StringConstants.au3>
#include <GuiEdit.au3>
#include <GDIPlus.au3>
#include <WinAPIShellEx.au3>
#include <WinAPIIcons.au3>
#include <WinAPIHObj.au3>
#include <WinAPIProc.au3>
#include <FileConstants.au3>
#include <Misc.au3>

; ============================================================
; CHARTE GRAPHIQUE ROUGEGORGE LINGERIE - elements communs
;
; Inclus par les applications d'inventaire et par le lanceur :
;   #include "RG_Charte.au3"
; Il est integre a chaque exe a la compilation, mais doit etre
; present a cote du script pour compiler (et publie avec lui).
;
; Contenu :
;   - couleurs et police de la charte ($RG_*) ;
;   - RG_ActiverMiseEchelleGDI() : textes nets sur ecran a 125 %... ;
;   - RG_Logo() : logo lisse a n'importe quelle taille ;
;   - RG_Bandeau() / RG_BandeauInfo() : bandeau rouge d'en-tete ;
;   - RG_TitreSection(), RG_Pastille(), RG_Filet(), RG_ChampRecherche() ;
;   - RG_Bouton() + RG_GererSurvol() : boutons plats avec survol ;
;   - RG_MsgBox() : boites de dialogue aux couleurs de la charte,
;     appelees comme MsgBox (memes parametres, memes retours) ;
;   - RG_InventaireDejaOuvert() : un seul inventaire ouvert a la fois ;
;   - RG_RamenerLanceurAuPremierPlan() : retour au lanceur a la fermeture.
;
; Tous les noms sont prefixes RG_ pour eviter tout conflit avec
; le code des applications.
; ============================================================

; ============================================
; Couleurs (0xRRGGBB) - rouge officiel Rougegorge : #EB0026
; ============================================
Global Const $RG_COUL_ROUGE = 0xEB0026         ; bandeau, bouton principal, liens, titres
Global Const $RG_COUL_ROUGE_FONCE = 0xB3001D   ; survol
Global Const $RG_COUL_ROSE_PALE = 0xFFD6DD     ; textes secondaires sur le bandeau
Global Const $RG_COUL_ROSE_FOND = 0xFDEAED     ; boutons secondaires, pastille, survol des cartes
Global Const $RG_COUL_ROSE_SURVOL = 0xFAD3DA   ; boutons secondaires survoles
Global Const $RG_COUL_FOND = 0xFAF6F3          ; fond ivoire des fenetres
Global Const $RG_COUL_BLANC = 0xFFFFFF
Global Const $RG_COUL_TEXTE = 0x2B2B2B         ; texte principal
Global Const $RG_COUL_TEXTE_DOUX = 0x7A7A7A    ; texte secondaire
Global Const $RG_COUL_FILET = 0xE8DEDA         ; lignes de separation
Global Const $RG_COUL_INACTIF = 0xBDBDBD       ; element indisponible
Global Const $RG_COUL_ATTENTION = 0xC26A00     ; etiquette "ATTENTION" des dialogues
Global Const $RG_POLICE = "Segoe UI"
Global Const $RG_POLICE_FINE = "Segoe UI Light"

; Types de boutons pour RG_Bouton()
Global Const $RG_BOUTON_PRINCIPAL = 1
Global Const $RG_BOUTON_SECONDAIRE = 2
Global Const $RG_BOUTON_LIEN = 3          ; lien gris (ex. "Quitter")
Global Const $RG_BOUTON_LIEN_ROUGE = 4    ; lien rouge (ex. "Effacer")

; Boutons enregistres pour le survol : [id, type, handle fenetre, survole]
Global $RG_aBoutons[0][4]

; ============================================
; Textes nets sur les ecrans mis a l'echelle (125 %, 150 %...)
;
; Sans cela, Windows etire toute la fenetre en bitmap : textes
; flous. La "mise a l'echelle GDI" (Windows 10 1809+) redessine
; les textes a la resolution reelle sans changer la mise en page.
; Les images restent etirees (logo legerement doux).
; DPI_AWARENESS_CONTEXT_UNAWARE_GDISCALED = -5. Sans effet sur un
; Windows plus ancien. A appeler AVANT la creation de toute fenetre.
;
; EVOLUTION POSSIBLE : gestion complete du DPI (toutes les
; coordonnees multipliees par l'echelle de l'ecran) pour un logo
; parfaitement net. Mise de cote le 08/10/2026.
; ============================================
Func RG_ActiverMiseEchelleGDI()
    DllCall("user32.dll", "bool", "SetProcessDpiAwarenessContext", "handle", -5)
EndFunc

; Icone : celle embarquee dans l'exe une fois compile,
; sinon logo-RG.ico a cote du script
Func RG_FichierIcone()
    If @Compiled Then Return @AutoItExe
    Return @ScriptDir & "\logo-RG.ico"
EndFunc

; ============================================
; Logo net : l'image 256 px de l'icone est reduite en bicubique
; haute qualite (GDI+), au lieu de GUICtrlCreateIcon qui reduit
; sans lissage. Le logo est opaque : la perte de transparence
; de _GDIPlus_BitmapCreateFromHICON est sans effet.
; L'image affichee n'est volontairement pas liberee : selon son
; format, le controle l'utilise sans en faire de copie.
; ============================================
Func RG_Logo($iX, $iY, $iTaille)
    Local $idPic = GUICtrlCreatePic("", $iX, $iY, $iTaille, $iTaille)
    Local $hIcone = _WinAPI_ShellExtractIcon(RG_FichierIcone(), 0, 256, 256)
    If Not $hIcone Then Return $idPic

    _GDIPlus_Startup()
    Local $hSource = _GDIPlus_BitmapCreateFromHICON($hIcone)
    Local $hReduit = _GDIPlus_ImageResize($hSource, $iTaille, $iTaille, $GDIP_INTERPOLATIONMODE_HIGHQUALITYBICUBIC)
    Local $hBmp = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hReduit)
    _WinAPI_DeleteObject(GUICtrlSendMsg($idPic, 0x0172, 0, $hBmp)) ; STM_SETIMAGE, IMAGE_BITMAP
    _GDIPlus_ImageDispose($hReduit)
    _GDIPlus_ImageDispose($hSource)
    _GDIPlus_Shutdown()
    _WinAPI_DestroyIcon($hIcone)
    Return $idPic
EndFunc

; ============================================
; Bandeau rouge d'en-tete : logo, titre, "ROUGEGORGE LINGERIE"
; Le fond est un libelle desactive : il ne capte pas les clics.
; ============================================
Func RG_Bandeau($iLargeur, $iHauteur, $sTitre, $bSousTitre = True)
    GUICtrlCreateLabel("", 0, 0, $iLargeur, $iHauteur)
    GUICtrlSetBkColor(-1, $RG_COUL_ROUGE)
    GUICtrlSetState(-1, $GUI_DISABLE)

    Local $iLogo = Int($iHauteur * 0.55)
    Local $iYLogo = Int(($iHauteur - $iLogo) / 2)
    RG_Logo(24, $iYLogo, $iLogo)

    Local $iXTexte = 24 + $iLogo + 16
    Local $id
    If $bSousTitre Then
        $id = GUICtrlCreateLabel($sTitre, $iXTexte, $iYLogo - 8, $iLargeur - $iXTexte - 260, 38)
        GUICtrlSetFont($id, 20, 300, 0, $RG_POLICE_FINE, 5)
        GUICtrlSetColor($id, $RG_COUL_BLANC)
        GUICtrlSetBkColor($id, $GUI_BKCOLOR_TRANSPARENT)
        $id = GUICtrlCreateLabel("R O U G E G O R G E    L I N G E R I E", $iXTexte + 2, $iYLogo + $iLogo - 12, 400, 16)
        GUICtrlSetFont($id, 7.5, 600, 0, $RG_POLICE, 5)
        GUICtrlSetColor($id, $RG_COUL_ROSE_PALE)
        GUICtrlSetBkColor($id, $GUI_BKCOLOR_TRANSPARENT)
    Else
        $id = GUICtrlCreateLabel($sTitre, $iXTexte, 0, $iLargeur - $iXTexte - 16, $iHauteur, $SS_CENTERIMAGE)
        GUICtrlSetFont($id, 15, 300, 0, $RG_POLICE_FINE, 5)
        GUICtrlSetColor($id, $RG_COUL_BLANC)
        GUICtrlSetBkColor($id, $GUI_BKCOLOR_TRANSPARENT)
    EndIf
EndFunc

; Information a droite du bandeau (ex. "PROCHAIN INVENTAIRE" / "IVC127")
; Retourne l'identifiant du libelle de la valeur (pour la mettre a jour).
Func RG_BandeauInfo($iLargeur, $sLibelle, $sValeur)
    Local $id = GUICtrlCreateLabel($sLibelle, $iLargeur - 254, 16, 230, 16, $SS_RIGHT)
    GUICtrlSetFont($id, 7.5, 600, 0, $RG_POLICE, 5)
    GUICtrlSetColor($id, $RG_COUL_ROSE_PALE)
    GUICtrlSetBkColor($id, $GUI_BKCOLOR_TRANSPARENT)
    $id = GUICtrlCreateLabel($sValeur, $iLargeur - 254, 32, 230, 34, $SS_RIGHT)
    GUICtrlSetFont($id, 18, 400, 0, $RG_POLICE, 5)
    GUICtrlSetColor($id, $RG_COUL_BLANC)
    GUICtrlSetBkColor($id, $GUI_BKCOLOR_TRANSPARENT)
    Return $id
EndFunc

; Titre de section en petites capitales rouges
Func RG_TitreSection($sTexte, $iX, $iY, $iL)
    Local $id = GUICtrlCreateLabel($sTexte, $iX, $iY, $iL, 18, $SS_NOPREFIX)
    GUICtrlSetFont($id, 8.5, 700, 0, $RG_POLICE, 5)
    GUICtrlSetColor($id, $RG_COUL_ROUGE)
    Return $id
EndFunc

; Pastille d'information (ex. compteur de selection)
Func RG_Pastille($sTexte, $iX, $iY, $iL, $iH = 30)
    Local $id = GUICtrlCreateLabel($sTexte, $iX, $iY, $iL, $iH, BitOR($SS_CENTER, $SS_CENTERIMAGE, $SS_NOPREFIX))
    GUICtrlSetFont($id, 9.5, 600, 0, $RG_POLICE, 5)
    GUICtrlSetColor($id, $RG_COUL_ROUGE)
    GUICtrlSetBkColor($id, $RG_COUL_ROSE_FOND)
    Return $id
EndFunc

; Ligne de separation horizontale
Func RG_Filet($iX, $iY, $iL)
    Local $id = GUICtrlCreateLabel("", $iX, $iY, $iL, 1)
    GUICtrlSetBkColor($id, $RG_COUL_FILET)
    GUICtrlSetState($id, $GUI_DISABLE)
    Return $id
EndFunc

; Texte simple (couleur et taille au choix)
Func RG_Texte($sTexte, $iX, $iY, $iL, $iH, $fTaille = 10, $iCouleur = $RG_COUL_TEXTE_DOUX, $iStyle = 0, $iGraisse = 400)
    Local $id = GUICtrlCreateLabel($sTexte, $iX, $iY, $iL, $iH, BitOR($SS_NOPREFIX, $iStyle))
    GUICtrlSetFont($id, $fTaille, $iGraisse, 0, $RG_POLICE, 5)
    GUICtrlSetColor($id, $iCouleur)
    Return $id
EndFunc

; Champ de saisie avec texte indicatif grise tant qu'il est vide
Func RG_ChampRecherche($iX, $iY, $iL, $sIndication = "Rechercher un article...")
    Local $id = GUICtrlCreateInput("", $iX, $iY, $iL, 30)
    GUICtrlSetFont($id, 11, 400, 0, $RG_POLICE, 5)
    ; True : texte indicatif visible meme quand le champ a le focus
    ; (il l'a a l'ouverture de la fenetre)
    _GUICtrlEdit_SetCueBanner(GUICtrlGetHandle($id), $sIndication, True)
    Return $id
EndFunc

; ============================================
; BOUTONS PLATS
;
; Un bouton est un libelle cliquable : GUIGetMsg() renvoie son
; identifiant comme pour un bouton classique. Appeler
; RG_GererSurvol($hFenetre) dans la boucle de la fenetre pour
; l'effet de survol.
; ============================================
Func RG_Bouton($sTexte, $iX, $iY, $iL, $iH = 40, $iType = $RG_BOUTON_PRINCIPAL)
    Local $iStyle = BitOR($SS_NOTIFY, $SS_CENTERIMAGE, $SS_NOPREFIX)
    If $iType = $RG_BOUTON_PRINCIPAL Or $iType = $RG_BOUTON_SECONDAIRE Then $iStyle = BitOR($iStyle, $SS_CENTER)
    Local $id = GUICtrlCreateLabel($sTexte, $iX, $iY, $iL, $iH, $iStyle)
    Local $fTaille = 10
    If $iType = $RG_BOUTON_PRINCIPAL Then $fTaille = 10.5
    GUICtrlSetFont($id, $fTaille, 600, 0, $RG_POLICE, 5)
    GUICtrlSetCursor($id, 0)

    Local $iN = UBound($RG_aBoutons)
    ReDim $RG_aBoutons[$iN + 1][4]
    $RG_aBoutons[$iN][0] = $id
    $RG_aBoutons[$iN][1] = $iType
    $RG_aBoutons[$iN][2] = _RG_FenetreDuControle($id)
    $RG_aBoutons[$iN][3] = False
    _RG_ColorerBouton($iN, False)
    Return $id
EndFunc

Func _RG_FenetreDuControle($id)
    Local $aRet = DllCall("user32.dll", "hwnd", "GetParent", "hwnd", GUICtrlGetHandle($id))
    If @error Then Return 0
    Return $aRet[0]
EndFunc

Func _RG_ColorerBouton($i, $bSurvol)
    Local $id = $RG_aBoutons[$i][0]
    Switch $RG_aBoutons[$i][1]
        Case $RG_BOUTON_PRINCIPAL
            GUICtrlSetColor($id, $RG_COUL_BLANC)
            GUICtrlSetBkColor($id, $bSurvol ? $RG_COUL_ROUGE_FONCE : $RG_COUL_ROUGE)
        Case $RG_BOUTON_SECONDAIRE
            GUICtrlSetColor($id, $bSurvol ? $RG_COUL_ROUGE_FONCE : $RG_COUL_ROUGE)
            GUICtrlSetBkColor($id, $bSurvol ? $RG_COUL_ROSE_SURVOL : $RG_COUL_ROSE_FOND)
        Case $RG_BOUTON_LIEN
            GUICtrlSetColor($id, $bSurvol ? $RG_COUL_ROUGE : $RG_COUL_TEXTE_DOUX)
        Case $RG_BOUTON_LIEN_ROUGE
            GUICtrlSetColor($id, $bSurvol ? $RG_COUL_ROUGE_FONCE : $RG_COUL_ROUGE)
    EndSwitch
    $RG_aBoutons[$i][3] = $bSurvol
EndFunc

; Met a jour l'effet de survol des boutons de la fenetre.
; GUIGetCursorInfo ne fonctionne que sur la fenetre active :
; c'est le cas en usage normal.
Func RG_GererSurvol($hFenetre)
    Local $aInfo = GUIGetCursorInfo($hFenetre)
    Local $idSous = 0
    If IsArray($aInfo) Then $idSous = $aInfo[4]
    For $i = 0 To UBound($RG_aBoutons) - 1
        If $RG_aBoutons[$i][2] <> $hFenetre Then ContinueLoop
        Local $bSurvol = ($RG_aBoutons[$i][0] = $idSous)
        If $bSurvol <> $RG_aBoutons[$i][3] Then _RG_ColorerBouton($i, $bSurvol)
    Next
EndFunc

; Retire du suivi les boutons d'une fenetre supprimee
Func RG_OublierBoutons($hFenetre)
    Local $aGarde[0][4], $iN = 0
    For $i = 0 To UBound($RG_aBoutons) - 1
        If $RG_aBoutons[$i][2] = $hFenetre Then ContinueLoop
        ReDim $aGarde[$iN + 1][4]
        For $c = 0 To 3
            $aGarde[$iN][$c] = $RG_aBoutons[$i][$c]
        Next
        $iN += 1
    Next
    $RG_aBoutons = $aGarde
EndFunc

; ============================================
; BOITES DE DIALOGUE AUX COULEURS DE LA CHARTE
;
; Remplace MsgBox avec les memes parametres et les memes retours :
;   RG_MsgBox($MB_ICONERROR + $MB_TOPMOST, "Titre", "Texte")      -> $IDOK
;   RG_MsgBox($MB_ICONQUESTION + $MB_YESNO, "Titre", "Texte")      -> $IDYES / $IDNO
;
; Bandeau rouge avec le titre, etiquette de type (ERREUR,
; ATTENTION, CONFIRMATION, INFORMATION), texte, puis boutons.
; La hauteur s'adapte a la longueur du texte.
; Entree = bouton principal (OK / Oui), Echap ou croix = Non / OK.
; La fenetre appelante est desactivee pendant l'affichage.
; ============================================
Func RG_MsgBox($iFlag, $sTitre, $sTexte)
    Local Const $iL = 480, $iMarge = 24, $iLargeurTexte = $iL - 2 * $iMarge
    Local $bOuiNon = (BitAND($iFlag, 0xF) = $MB_YESNO)

    Local $sEtiquette = "INFORMATION", $iCoulEtiquette = $RG_COUL_TEXTE_DOUX
    Switch BitAND($iFlag, 0xF0)
        Case $MB_ICONERROR
            $sEtiquette = "ERREUR"
            $iCoulEtiquette = $RG_COUL_ROUGE
        Case $MB_ICONWARNING
            $sEtiquette = "ATTENTION"
            $iCoulEtiquette = $RG_COUL_ATTENTION
        Case $MB_ICONQUESTION
            $sEtiquette = "CONFIRMATION"
            $iCoulEtiquette = $RG_COUL_ROUGE
    EndSwitch

    ; Hauteur du texte, mesuree avec la police reelle. Marge de 20 % :
    ; avec la mise a l'echelle GDI, l'interligne affiche est un peu
    ; plus grand que celui mesure (constate a 125 %).
    Local $iHTexte = Int(_RG_HauteurTexte($sTexte, $iLargeurTexte, 10) * 1.2) + 6
    If $iHTexte < 22 Then $iHTexte = 22
    If $iHTexte > 520 Then $iHTexte = 520

    Local $iYTexte = 52 + 22 + 26
    Local $iYFilet = $iYTexte + $iHTexte + 18
    Local $iYBoutons = $iYFilet + 16
    Local $iH = $iYBoutons + 38 + 20

    ; Fenetre appelante (si elle appartient a cette application)
    Local $hParent = WinGetHandle("[ACTIVE]")
    If WinGetProcess($hParent) <> @AutoItPID Then $hParent = 0

    Local $hDlg = GUICreate($sTitre, $iL, $iH, -1, -1, BitOR($WS_CAPTION, $WS_POPUP, $WS_SYSMENU), $WS_EX_TOPMOST, $hParent)
    GUISetIcon(RG_FichierIcone(), -1, $hDlg)
    GUISetBkColor($RG_COUL_FOND, $hDlg)
    GUISetFont(10, 400, 0, $RG_POLICE, $hDlg, 5)

    RG_Bandeau($iL, 52, $sTitre, False)
    RG_Texte($sEtiquette, $iMarge, 52 + 22, $iLargeurTexte, 18, 8.5, $iCoulEtiquette, 0, 700)
    RG_Texte($sTexte, $iMarge, $iYTexte, $iLargeurTexte, $iHTexte, 10, $RG_COUL_TEXTE)
    RG_Filet($iMarge, $iYFilet, $iLargeurTexte)

    Local $idPrincipal, $idSecondaire = -1
    If $bOuiNon Then
        $idSecondaire = RG_Bouton("Non", $iL - $iMarge - 120 - 12 - 120, $iYBoutons, 120, 38, $RG_BOUTON_SECONDAIRE)
        $idPrincipal = RG_Bouton("Oui", $iL - $iMarge - 120, $iYBoutons, 120, 38, $RG_BOUTON_PRINCIPAL)
    Else
        $idPrincipal = RG_Bouton("OK", $iL - $iMarge - 120, $iYBoutons, 120, 38, $RG_BOUTON_PRINCIPAL)
    EndIf

    ; Clavier : Entree = bouton principal
    Local $idEntree = GUICtrlCreateDummy()
    Local $aAccel[1][2] = [["{ENTER}", $idEntree]]
    GUISetAccelerators($aAccel, $hDlg)

    If $hParent Then GUISetState(@SW_DISABLE, $hParent)
    GUISetState(@SW_SHOW, $hDlg)
    WinActivate($hDlg)

    Local $iRetour = $bOuiNon ? $IDNO : $IDOK
    While 1
        Local $aMsg = GUIGetMsg(1)
        If $aMsg[1] = $hDlg Then
            Switch $aMsg[0]
                Case $idPrincipal, $idEntree
                    $iRetour = $bOuiNon ? $IDYES : $IDOK
                    ExitLoop
                Case $GUI_EVENT_CLOSE
                    ExitLoop
                Case $idSecondaire
                    If $idSecondaire <> -1 Then ExitLoop
            EndSwitch
        EndIf
        RG_GererSurvol($hDlg)
    WEnd

    If $hParent Then GUISetState(@SW_ENABLE, $hParent)
    RG_OublierBoutons($hDlg)
    GUIDelete($hDlg)
    If $hParent Then
        GUISwitch($hParent)
        WinActivate($hParent)
    EndIf
    Return $iRetour
EndFunc

; Hauteur en pixels d'un texte mis en forme sur une largeur donnee
; (meme calcul de retour a la ligne qu'un libelle Windows)
Func _RG_HauteurTexte($sTexte, $iLargeur, $fTaille)
    Local $aDC = DllCall("user32.dll", "handle", "GetDC", "hwnd", 0)
    If @error Then Return 20 * (UBound(StringSplit($sTexte, @LF, $STR_NOCOUNT)) + 1)
    Local $hDC = $aDC[0]
    Local $aDpi = DllCall("gdi32.dll", "int", "GetDeviceCaps", "handle", $hDC, "int", 90) ; LOGPIXELSY
    Local $iHauteurPolice = -Round($fTaille * $aDpi[0] / 72)
    Local $aFont = DllCall("gdi32.dll", "handle", "CreateFontW", "int", $iHauteurPolice, "int", 0, "int", 0, "int", 0, _
            "int", 400, "dword", 0, "dword", 0, "dword", 0, "dword", 1, "dword", 0, "dword", 0, "dword", 5, "dword", 0, _
            "wstr", $RG_POLICE)
    Local $aAncien = DllCall("gdi32.dll", "handle", "SelectObject", "handle", $hDC, "handle", $aFont[0])
    Local $tRect = DllStructCreate("long;long;long;long")
    DllStructSetData($tRect, 3, $iLargeur)
    ; DT_CALCRECT 0x400 | DT_WORDBREAK 0x10 | DT_NOPREFIX 0x800 | DT_EXPANDTABS 0x40
    DllCall("user32.dll", "int", "DrawTextW", "handle", $hDC, "wstr", $sTexte, "int", -1, "struct*", $tRect, "uint", 0xC50)
    Local $iHauteur = DllStructGetData($tRect, 4)
    DllCall("gdi32.dll", "handle", "SelectObject", "handle", $hDC, "handle", $aAncien[0])
    DllCall("gdi32.dll", "bool", "DeleteObject", "handle", $aFont[0])
    DllCall("user32.dll", "int", "ReleaseDC", "hwnd", 0, "handle", $hDC)
    Return $iHauteur
EndFunc

; ============================================================
; UN SEUL INVENTAIRE OUVERT A LA FOIS
;
; Mutex commun aux applications d'inventaire (le lanceur n'est
; pas concerne). Appeler RG_InventaireDejaOuvert() au debut de
; Main(), apres RG_ActiverMiseEchelleGDI() :
;
;   - aucun inventaire ouvert : retourne "", on continue ;
;   - le MEME inventaire est deja ouvert : sa fenetre revient au
;     premier plan, sans message, et la fonction retourne son nom ;
;   - un AUTRE inventaire est ouvert : message "L'inventaire X est
;     deja ouvert...", sa fenetre revient au premier plan, et la
;     fonction retourne son nom.
; Dans les deux derniers cas, l'application doit se fermer.
;
; L'inventaire ouvert est identifie par le NOM DU PRODUIT integre
; a son exe (celui affiche par le Gestionnaire des taches) et non
; par le nom du fichier : renommer un exe n'a donc aucun impact.
; Tout produit commencant par "RG - Inventaire" est un inventaire
; (le lanceur, "RG - Lanceur Inventaires", n'en est pas un).
; ============================================================
Global Const $RG_MUTEX_INVENTAIRES = "RG_Inventaires_Instance_Unique"
Global Const $RG_PREFIXE_INVENTAIRE = "RG - Inventaire"

Func RG_InventaireDejaOuvert($sNomApplication)
    ; Mutex obtenu : aucun autre inventaire n'est ouvert. Il reste
    ; detenu jusqu'a la fermeture de l'application.
    If _Singleton($RG_MUTEX_INVENTAIRES, 1) <> 0 Then Return ""

    ; Nom de cette application : celui de son exe une fois compile
    Local $sMoi = $sNomApplication
    If @Compiled Then $sMoi = _RG_NomInventaire(FileGetVersion(@AutoItExe, $FV_PRODUCTNAME), $sNomApplication)

    ; Recherche de l'inventaire deja ouvert
    Local $iPidAutre = 0, $sAutre = ""
    Local $aProc = ProcessList()
    For $i = 1 To $aProc[0][0]
        Local $iPid = $aProc[$i][1]
        ; PID 0 et 4 : processus systeme. Attention, _WinAPI_GetProcessFileName(0)
        ; renvoie le chemin du processus COURANT : sans ce filtre, l'application
        ; se trouverait elle-meme et se fermerait sans message.
        If $iPid <= 4 Or $iPid = @AutoItPID Then ContinueLoop
        Local $sChemin = _WinAPI_GetProcessFileName($iPid)
        If $sChemin = "" Then ContinueLoop
        Local $sProduit = FileGetVersion($sChemin, $FV_PRODUCTNAME)
        If StringLeft($sProduit, StringLen($RG_PREFIXE_INVENTAIRE)) <> $RG_PREFIXE_INVENTAIRE Then ContinueLoop
        $iPidAutre = $iPid
        $sAutre = _RG_NomInventaire($sProduit, "")
        ExitLoop
    Next

    ; Meme inventaire relance : simple retour au premier plan
    If $sAutre <> "" And $sAutre = $sMoi Then
        RG_ActiverFenetreProcessus($iPidAutre)
        Return $sAutre
    EndIf

    Local $sMsg
    If $sAutre = "" Then
        $sAutre = "Un autre inventaire"
        $sMsg = "Un autre inventaire est déjà ouvert."
    Else
        $sMsg = "L'" & _RG_MinusculeInitiale($sAutre) & " est déjà ouvert."
    EndIf
    $sMsg &= @CRLF & @CRLF & "Terminez-le ou fermez-le avant d'ouvrir" & @CRLF & _
            "l'" & _RG_MinusculeInitiale($sMoi) & "."
    RG_MsgBox($MB_ICONWARNING + $MB_TOPMOST, $sMoi, $sMsg)
    If $iPidAutre Then RG_ActiverFenetreProcessus($iPidAutre)
    Return $sAutre
EndFunc

; "RG - Inventaire Prix Ronds" -> "Inventaire Prix Ronds"
Func _RG_NomInventaire($sProduit, $sDefaut)
    If StringLeft($sProduit, StringLen($RG_PREFIXE_INVENTAIRE)) <> $RG_PREFIXE_INVENTAIRE Then Return $sDefaut
    Return StringStripWS(StringTrimLeft($sProduit, StringLen("RG - ")), 3)
EndFunc

; "Inventaire Prix Ronds" -> "inventaire Prix Ronds" (pour "L'inventaire...")
Func _RG_MinusculeInitiale($s)
    Return StringLower(StringLeft($s, 1)) & StringTrimLeft($s, 1)
EndFunc

; ============================================
; Remet au premier plan la fenetre visible d'un processus.
; Retourne False si aucune fenetre n'a ete trouvee.
; ============================================
Func RG_ActiverFenetreProcessus($iPid)
    If Not $iPid Then Return False
    Local $aFen = WinList()
    For $i = 1 To $aFen[0][0]
        If $aFen[$i][0] = "" Then ContinueLoop
        Local $hFen = $aFen[$i][1]
        If WinGetProcess($hFen) <> $iPid Then ContinueLoop
        Local $iEtat = WinGetState($hFen)
        If Not BitAND($iEtat, $WIN_STATE_VISIBLE) Then ContinueLoop
        If BitAND($iEtat, $WIN_STATE_MINIMIZED) Then WinSetState($hFen, "", @SW_RESTORE)
        WinActivate($hFen)
        Return True
    Next
    Return False
EndFunc

; ============================================================
; RETOUR AU LANCEUR A LA FERMETURE D'UN INVENTAIRE
;
; Titre de la fenetre du lanceur : defini ICI une seule fois,
; utilise par le lanceur pour sa fenetre et par les inventaires
; pour la retrouver.
;
; Les inventaires enregistrent RG_RamenerLanceurAuPremierPlan avec
; OnAutoItExitRegister au debut de Main(), APRES le controle
; RG_InventaireDejaOuvert : elle s'execute a toute fermeture
; (fin normale, Quitter, croix, Exit apres une erreur). Un
; inventaire refuse (autre inventaire deja ouvert) ne l'a pas
; encore enregistree : il ramene l'inventaire ouvert, pas le lanceur.
; Sans lanceur ouvert, la fonction ne fait rien.
; ============================================================
Global Const $RG_TITRE_LANCEUR = "Inventaires - Rougegorge Lingerie"

Func RG_RamenerLanceurAuPremierPlan()
    Local $hFen = WinGetHandle("[TITLE:" & $RG_TITRE_LANCEUR & "; CLASS:AutoIt v3 GUI]")
    If @error Then Return
    If BitAND(WinGetState($hFen), $WIN_STATE_MINIMIZED) Then WinSetState($hFen, "", @SW_RESTORE)
    WinActivate($hFen)
EndFunc