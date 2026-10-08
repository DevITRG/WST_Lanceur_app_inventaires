#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=logo-RG.ico
#AutoIt3Wrapper_Res_Fileversion=1.0.0.3
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_Description=RG - Inventaires
#AutoIt3Wrapper_Res_ProductName=RG - Lanceur Inventaires
#AutoIt3Wrapper_Res_ProductVersion=%fileversion%
#AutoIt3Wrapper_Res_CompanyName=Rougegorge Lingerie
#AutoIt3Wrapper_Res_LegalCopyright=Rougegorge Lingerie
#AutoIt3Wrapper_Res_Language=1036
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <AutoItConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <MsgBoxConstants.au3>
#include <FileConstants.au3>
#include <Misc.au3>
; Charte graphique Rougegorge commune (couleurs, logo, boutons,
; boites de dialogue RG_MsgBox). Doit etre a cote du script.
#include "RG_Charte.au3"

; ============================================================
; LANCEUR D'INVENTAIRES - Rougegorge Lingerie
;
; Point d'entree unique pour les applications d'inventaire :
; une carte par application, un clic lance l'inventaire choisi.
;
; - Instance unique (mutex) : relancer le lanceur ramene au
;   premier plan la fenetre deja ouverte au lieu d'en ouvrir
;   une seconde.
; - Si l'inventaire choisi est deja ouvert, sa fenetre est
;   ramenee au premier plan au lieu d'en lancer un second
;   (deux inventaires simultanes se bloqueraient sur Transfer.txt).
; - Une application absente est affichee grisee ("introuvable").
; ============================================================

; ============================================
; Configuration
; ============================================
; Titre de la fenetre : sert aussi a retrouver l'instance deja
; ouverte. Il doit rester unique.
Global Const $g_sTitreFenetre = "Inventaires - Rougegorge Lingerie"
Global Const $g_sNomMutex = "RG_Lanceur_Inventaires"

; Dossier contenant les applications d'inventaire (.exe)
Global $g_sDossierApplis = @ScriptDir

; Applications proposees : [Libelle, Description, Fichier exe]
; Pour ajouter une application : ajouter une ligne et augmenter
; la premiere dimension. La fenetre s'agrandit automatiquement.
Global $g_aApplis[3][3] = [ _
        ["Inventaire à la saison", "Articles à stock non nul, sélectionnés par saison", "inventaire_saison.exe"], _
        ["Inventaire Prix Ronds", "Articles en opération Prix Rond, à stock non nul", "inventaire_prix_ronds.exe"], _
        ["Inventaire stock négatif", "Articles dont le stock est négatif", "inventaire_stock_negatif.exe"]]

; ============================================
; Journalisation (meme fonctionnement que les applications
; d'inventaire). Le lanceur ne trace que les erreurs : chaque
; application trace deja son propre lancement.
; ============================================
Global $g_sFichierLog = "C:\Winstore\log\winstore.log"
Global $g_sTagLog = "[Inv Lanceur]"
Global $g_sFormatLog = "{date} {heure} : {tag} {message}"

; ============================================
; Charte graphique : couleurs et police communes ($RG_*),
; definies dans RG_Charte.au3 (rouge officiel #EB0026)
; ============================================

; ============================================
; Geometrie
; ============================================
Global Const $LARGEUR = 480
Global Const $HAUTEUR_BANDEAU = 104
Global Const $Y_CARTES = 160
Global Const $HAUTEUR_CARTE = 78
Global Const $ECART_CARTES = 14

; Identifiants des controles de chaque carte :
; [0] accent, [1] marge gauche, [2] titre, [3] version, [4] description, [5] marge droite
Global $g_aCartes[UBound($g_aApplis)][6]
Global $g_aDispo[UBound($g_aApplis)]

; ============================================
; JOURNALISATION
; ============================================
Func EcrireLog($sMessage)
    ConsoleWrite("[Log] " & $sMessage & @CRLF)
    If $g_sFichierLog = "" Then Return

    Local $sLigne = $g_sFormatLog
    $sLigne = StringReplace($sLigne, "{date}", StringFormat("%02d/%02d/%04d", @MDAY, @MON, @YEAR))
    $sLigne = StringReplace($sLigne, "{heure}", StringFormat("%02d:%02d:%02d", @HOUR, @MIN, @SEC))
    $sLigne = StringReplace($sLigne, "{tag}", $g_sTagLog)
    $sLigne = StringReplace($sLigne, "{message}", StringRegExpReplace($sMessage, "\s+", " "))

    For $iEssai = 1 To 3
        Local $hLog = FileOpen($g_sFichierLog, BitOR($FO_APPEND, $FO_CREATEPATH, $FO_ANSI))
        If $hLog <> -1 Then
            FileWriteLine($hLog, $sLigne)
            FileClose($hLog)
            Return
        EndIf
        Sleep(200)
    Next
EndFunc

Func VersionApplication()
    If Not @Compiled Then Return "script non compilé"
    Return "v" & FileGetVersion(@AutoItExe)
EndFunc

; ============================================
; INSTANCE UNIQUE
; Appelee par une seconde instance : remet au premier plan
; la fenetre du lanceur deja ouvert, puis la seconde instance
; se ferme.
; ============================================
Func RamenerInstanceExistante()
    Local $hFen = WinGetHandle("[TITLE:" & $g_sTitreFenetre & "; CLASS:AutoIt v3 GUI]")
    If @error Then Return
    If BitAND(WinGetState($hFen), $WIN_STATE_MINIMIZED) Then WinSetState($hFen, "", @SW_RESTORE)
    WinActivate($hFen)
EndFunc

; ============================================
; Remet au premier plan la fenetre visible d'un processus
; (inventaire deja ouvert). Retourne False si aucune fenetre.
; ============================================
Func ActiverFenetreProcessus($iPid)
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

; ============================================
; Lancement d'une application d'inventaire
; ============================================
Func LancerApplication($i)
    Local $sNom = $g_aApplis[$i][0]
    Local $sExe = $g_aApplis[$i][2]
    Local $sChemin = $g_sDossierApplis & "\" & $sExe

    If Not FileExists($sChemin) Then
        EcrireLog("ERREUR : " & $sNom & " introuvable (" & $sChemin & ")")
        RG_MsgBox($MB_ICONERROR + $MB_TOPMOST, $sNom, _
                "Cette application est introuvable." & @CRLF & @CRLF & _
                "Merci de contacter la Hotline.")
        Return
    EndIf

    ; Deja ouverte : on la ramene au premier plan plutot que d'en lancer une seconde
    Local $iPid = ProcessExists($sExe)
    If $iPid Then
        ActiverFenetreProcessus($iPid)
        Return
    EndIf

    $iPid = Run('"' & $sChemin & '"', $g_sDossierApplis)
    If $iPid = 0 Then
        EcrireLog("ERREUR : lancement de " & $sNom & " impossible (" & $sChemin & ")")
        RG_MsgBox($MB_ICONERROR + $MB_TOPMOST, $sNom, _
                "L'application n'a pas pu être lancée." & @CRLF & @CRLF & _
                "Merci de contacter la Hotline.")
    EndIf
EndFunc

; ============================================
; CARTES
; ============================================

; Cree une carte cliquable, faite de libelles juxtaposes
; (sans chevauchement, pour un survol sans scintillement)
;
;   | accent | marge | titre .............. version | marge |
;   |        |       | description ................ |       |
Func CreerCarte($i, $iY)
    Local $iX = 30, $iW = $LARGEUR - 60, $iH = $HAUTEUR_CARTE, $iHTitre = 46
    Local $sChemin = $g_sDossierApplis & "\" & $g_aApplis[$i][2]
    $g_aDispo[$i] = FileExists($sChemin)

    Local $sVersion = "introuvable"
    If $g_aDispo[$i] Then $sVersion = "v" & FileGetVersion($sChemin)

    Local $iStyle = $SS_NOTIFY
    $g_aCartes[$i][0] = GUICtrlCreateLabel("", $iX, $iY, 6, $iH, $iStyle)
    $g_aCartes[$i][1] = GUICtrlCreateLabel("", $iX + 6, $iY, 18, $iH, $iStyle)
    $g_aCartes[$i][2] = GUICtrlCreateLabel($g_aApplis[$i][0], $iX + 24, $iY, $iW - 24 - 126, $iHTitre, _
            BitOR($iStyle, $SS_CENTERIMAGE))
    $g_aCartes[$i][3] = GUICtrlCreateLabel($sVersion, $iX + $iW - 126, $iY, 110, $iHTitre, _
            BitOR($iStyle, $SS_CENTERIMAGE, $SS_RIGHT))
    $g_aCartes[$i][4] = GUICtrlCreateLabel($g_aApplis[$i][1], $iX + 24, $iY + $iHTitre, $iW - 24 - 16, $iH - $iHTitre, $iStyle)
    $g_aCartes[$i][5] = GUICtrlCreateLabel("", $iX + $iW - 16, $iY, 16, $iH, $iStyle)

    GUICtrlSetFont($g_aCartes[$i][2], 13, 600, 0, $RG_POLICE, 5)
    GUICtrlSetFont($g_aCartes[$i][3], 8.5, 400, 0, $RG_POLICE, 5)
    GUICtrlSetFont($g_aCartes[$i][4], 9.5, 400, 0, $RG_POLICE, 5)

    If $g_aDispo[$i] Then
        GUICtrlSetColor($g_aCartes[$i][2], $RG_COUL_TEXTE)
        GUICtrlSetColor($g_aCartes[$i][3], $RG_COUL_TEXTE_DOUX)
        GUICtrlSetColor($g_aCartes[$i][4], $RG_COUL_TEXTE_DOUX)
        For $c = 0 To 5
            GUICtrlSetCursor($g_aCartes[$i][$c], 0) ; main
        Next
    Else
        For $c = 2 To 4
            GUICtrlSetColor($g_aCartes[$i][$c], $RG_COUL_INACTIF)
        Next
    EndIf
    ColorerCarte($i, False)
EndFunc

; Couleurs d'une carte : normale ou survolee
Func ColorerCarte($i, $bSurvol)
    Local $iFond = $RG_COUL_BLANC, $iAccent = $RG_COUL_ROUGE
    If Not $g_aDispo[$i] Then
        $iAccent = $RG_COUL_INACTIF
    ElseIf $bSurvol Then
        $iFond = $RG_COUL_ROSE_FOND
        $iAccent = $RG_COUL_ROUGE_FONCE
    EndIf
    GUICtrlSetBkColor($g_aCartes[$i][0], $iAccent)
    For $c = 1 To 5
        GUICtrlSetBkColor($g_aCartes[$i][$c], $iFond)
    Next
EndFunc

; Index de la carte contenant le controle, -1 sinon
Func IndexCarte($idCtrl)
    If $idCtrl <= 0 Then Return -1
    For $i = 0 To UBound($g_aCartes) - 1
        For $c = 0 To 5
            If $g_aCartes[$i][$c] = $idCtrl Then Return $i
        Next
    Next
    Return -1
EndFunc

; ============================================
; FENETRE PRINCIPALE
; ============================================
Func AfficherLanceur()
    Local $iNb = UBound($g_aApplis)
    Local $iYPied = $Y_CARTES + $iNb * ($HAUTEUR_CARTE + $ECART_CARTES) + 4
    Local $iHauteur = $iYPied + 36

    Local $hGUI = GUICreate($g_sTitreFenetre, $LARGEUR, $iHauteur)
    GUISetIcon(RG_FichierIcone(), -1, $hGUI)
    GUISetBkColor($RG_COUL_FOND, $hGUI)
    GUISetFont(10, 400, 0, $RG_POLICE)

    ; ===== Bandeau rouge (fond desactive : ne capte pas les clics) =====
    GUICtrlCreateLabel("", 0, 0, $LARGEUR, $HAUTEUR_BANDEAU)
    GUICtrlSetBkColor(-1, $RG_COUL_ROUGE)
    GUICtrlSetState(-1, $GUI_DISABLE)

    RG_Logo(28, 26, 52)

    Local $id = GUICtrlCreateLabel("Inventaires", 98, 18, 350, 42)
    GUICtrlSetFont($id, 24, 300, 0, "Segoe UI Light", 5)
    GUICtrlSetColor($id, 0xFFFFFF)
    GUICtrlSetBkColor($id, $GUI_BKCOLOR_TRANSPARENT)

    $id = GUICtrlCreateLabel("R O U G E G O R G E    L I N G E R I E", 100, 64, 350, 18)
    GUICtrlSetFont($id, 8, 600, 0, $RG_POLICE, 5)
    GUICtrlSetColor($id, $RG_COUL_ROSE_PALE)
    GUICtrlSetBkColor($id, $GUI_BKCOLOR_TRANSPARENT)

    ; ===== Invite =====
    $id = GUICtrlCreateLabel("Choisissez l'inventaire à réaliser", 30, 122, $LARGEUR - 60, 24)
    GUICtrlSetFont($id, 11, 400, 0, $RG_POLICE, 5)
    GUICtrlSetColor($id, $RG_COUL_TEXTE)

    ; ===== Cartes =====
    For $i = 0 To $iNb - 1
        CreerCarte($i, $Y_CARTES + $i * ($HAUTEUR_CARTE + $ECART_CARTES))
    Next

    ; ===== Pied de page =====
    $id = GUICtrlCreateLabel(VersionApplication(), 30, $iYPied + 6, 200, 18)
    GUICtrlSetFont($id, 8, 400, 0, $RG_POLICE, 5)
    GUICtrlSetColor($id, $RG_COUL_TEXTE_DOUX)

    Local $idQuitter = RG_Bouton("Quitter", $LARGEUR - 130, $iYPied + 2, 100, 24, $RG_BOUTON_LIEN_ROUGE)
    GUICtrlSetStyle($idQuitter, BitOR($SS_NOTIFY, $SS_RIGHT, $SS_CENTERIMAGE, $SS_NOPREFIX))

    GUISetState(@SW_SHOW, $hGUI)

    Local $iSurvol = -1
    While 1
        Local $iMsg = GUIGetMsg()
        Switch $iMsg
            Case $GUI_EVENT_CLOSE, $idQuitter
                ExitLoop
            Case Else
                ; Clic sur une carte (une application introuvable affiche un message)
                Local $iCarte = IndexCarte($iMsg)
                If $iCarte >= 0 Then LancerApplication($iCarte)
        EndSwitch

        ; ===== Survol des cartes =====
        Local $aInfo = GUIGetCursorInfo($hGUI)
        Local $iNouveau = -1
        If IsArray($aInfo) Then $iNouveau = IndexCarte($aInfo[4])
        If $iNouveau <> $iSurvol Then
            If $iSurvol >= 0 Then ColorerCarte($iSurvol, False)
            If $iNouveau >= 0 Then ColorerCarte($iNouveau, True)
            $iSurvol = $iNouveau
        EndIf

        ; ===== Survol du lien "Quitter" =====
        RG_GererSurvol($hGUI)
    WEnd

    RG_OublierBoutons($hGUI)
    GUIDelete($hGUI)
EndFunc

; ============================================
; PROGRAMME PRINCIPAL
; ============================================
Func Main()
    ; Instance unique : _Singleton cree un mutex nomme et retourne 0
    ; s'il existe deja (lanceur deja ouvert). Le mutex est libere
    ; automatiquement a la fermeture du lanceur.
    If _Singleton($g_sNomMutex, 1) = 0 Then
        RamenerInstanceExistante()
        Exit
    EndIf

    RG_ActiverMiseEchelleGDI()
    AfficherLanceur()
EndFunc

Main()
