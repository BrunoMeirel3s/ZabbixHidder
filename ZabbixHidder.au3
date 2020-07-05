;//ZabbixHidder
;//brunomeireles23@gmail.com


#include <Misc.au3>
#include <Array.au3>
#include <WinAPI.au3>

Global Const $VERSION = "1.0"

;//Sair se o programa já estiver sendo executado.
If _Singleton("MTT", 1) = 0 Then
	TrayTip("ZabbixHidder " & $VERSION, "Uma instância do programa já está em execução.", 2)
	Sleep(2000)
	Exit
EndIf

Opt('TrayAutoPause', 0)
Opt('TrayMenuMode', 3)

HotKeySet("!{h}", "HideCurrentWnd")
HotKeySet("!{g}", "RestoreLastWnd")
HotKeySet("!{j}", "HandleAltF4")
HotKeySet("!{k}", "RestoreAllWnd")
HotKeySet("+{esc}", "ExitS")
OnAutoItExitRegister("ExitS")




;//$aHiddenWndList = Array that contains handles of all hidden windows.
;//$aTrayItemHandles = Array that contains tray items that indicate names of hidden windows.
;//Elements of these 2 arrays must be perfectly in sync with each other.
Global $aHiddenWndList[0] = [], $aTrayItemHandles[0] = []
Global $hLastWnd ;//Handle of the last window that was hidden
Global $g_hTempParentGUI[48], $g_aTempWindowSize[48][2], $g_nIndex = 0 ;//Method 1 of hiding window
Global $bAltF4EndProcess = False, $bRestoreOnExit = False
Global $SEMAPHORE = 1
Global $esconderZabbix1 = False
Global $esconderZabbix2 = False


;$hTrayMenuShowSelectWnd = TrayCreateMenu("Restore Window")
$hTrayRestoreAllWnd = TrayCreateItem("Restaurar todas as janelas (Alt+K)") ;, $hTrayMenuShowSelectWnd)
TrayCreateItem("") ;//Create a straight line
$opt = TrayCreateMenu("Opções")
$hTrayAltF4EndProcess = TrayCreateItem("Alt-J força o fechamento de processos das janelas", $opt)
$hTrayRestoreOnExit = TrayCreateItem("Restura janelas escondidas ao sair", $opt)
$hTrayHelp = TrayCreateItem("Manual Rápido")
$hTrayExit = TrayCreateItem("Sair (Shift+Esc)")

TrayTip("ZabbixHidder " & $VERSION, "Pressione [Alt+G] para mostrar a última janela escondida." & @CRLF _
		 & "Adaptado por: Bruno Meireles.", 5)

RestoreLastShutdownWindows()

;//Utilizado para esconder exclusivamente a janela do Zabbix
While 1
	  $esconderZabbix1 = True
	  $esconderZabbix2 = True

	  If (WinExists("Zabbix: Zabbix - Mozilla Firefox") Or WinExists("Zabbix: Mapas de rede - Mozilla Firefox")) then
		 For $i = 0 To UBound($aHiddenWndList) - 1
			If ($aHiddenWndList[$i] == "Zabbix: Zabbix - Mozilla Firefox") Then
			   $esconderZabbix1 = false
			EndIf
		 Next
		 If $esconderZabbix1 == True Then
			   HideWnd(WinGetHandle("Zabbix: Zabbix - Mozilla Firefox"))
		 EndIf

		 For $i = 0 To UBound($aHiddenWndList) - 1
			If ($aHiddenWndList[$i] == "Zabbix: Mapas de rede - Mozilla Firefox") Then
			   $esconderZabbix2 = false
			EndIf
		 Next
		 If $esconderZabbix2 == True Then
			HideWnd(WinGetHandle("Zabbix: Mapas de rede - Mozilla Firefox"))
			ExitLoop
		 EndIf
	  EndIf
   WEnd

;//Loop Principal
While 1
	$hTrayMsg = TrayGetMsg()
	Switch $hTrayMsg
		Case $hTrayAltF4EndProcess
			ToggleOpt($bAltF4EndProcess, $hTrayAltF4EndProcess)
		Case $hTrayRestoreOnExit
			ToggleOpt($bRestoreOnExit, $hTrayRestoreOnExit)
		Case $hTrayRestoreAllWnd
			RestoreAllWnd()
		Case $hTrayExit
			ExitS()
		Case $hTrayHelp
			Help()
	EndSwitch

	For $i = 0 To UBound($aTrayItemHandles) - 1
		If $hTrayMsg = $aTrayItemHandles[$i] Then
			If $i < UBound($aHiddenWndList) Then
				RestoreWnd($aHiddenWndList[$i])
			EndIf
			ExitLoop
		EndIf
	Next
WEnd


Func ToggleOpt(ByRef $bFlag, ByRef $hTrayItem)
	$bFlag = Not $bFlag

	Local $nTrayItemState = TrayItemGetState($hTrayItem)
	If BitAND($nTrayItemState, 1) Then ;//CHECKED
		TrayItemSetState($hTrayItem, 4)
	ElseIf BitAND($nTrayItemState, 4) Then
		TrayItemSetState($hTrayItem, 1)
	EndIf

EndFunc   ;==>ToggleOpt


Func RestoreLastWnd()
	;//Restore window from top of hidden windows stack.
	If UBound($aHiddenWndList) Then
		RestoreWnd($aHiddenWndList[UBound($aHiddenWndList) - 1])
	EndIf
EndFunc   ;==>RestoreLastWnd


Func RestoreWnd($hfWnd)
	If ($SEMAPHORE == 0) Then
		Return
	EndIf
	$SEMAPHORE = 0
	Local $nIndex = _ArraySearch($aHiddenWndList, $hfWnd)
	WinSetState($hfWnd, "", @SW_SHOW)
	If $nIndex >= 0 Then
		If $nIndex < UBound($aTrayItemHandles) Then
			TrayItemDelete($aTrayItemHandles[$nIndex])
			_ArrayDelete($aTrayItemHandles, $nIndex)
		EndIf
		If $nIndex < UBound($aHiddenWndList) Then
			_ArrayDelete($aHiddenWndList, $nIndex)
		EndIf
		;//Delete window's name from log file
		$sLog = FileRead("MTTlog.txt")
		$sLogN = StringReplace($sLog, WinGetTitle($hfWnd), "")
		$fd = FileOpen("MTTlog.txt", 2)
		FileWrite($fd, $sLogN)
		FileClose($fd)
	EndIf
	$SEMAPHORE = 1
EndFunc   ;==>RestoreWnd


Func HideWnd($hfWnd, $nMethod = 0)
	WinSetState($hfWnd, "", @SW_HIDE) ;Traditional WinSetState method

	_ArrayAdd($aHiddenWndList, $hfWnd)
	$hTrayWnd = TrayCreateItem(WinGetTitle($hfWnd), -1, 0) ;, $hTrayMenuShowSelectWnd)
	_ArrayAdd($aTrayItemHandles, $hTrayWnd)
	;//Write window's name to log file for legacy restoration in case of unexpected crash.
	FileWrite("MTTlog.txt", WinGetTitle($hfWnd) & @CRLF)
	$hLastWnd = $hfWnd
EndFunc   ;==>HideWnd


Func HideCurrentWnd()
	;//Hide currently active window.
	HideWnd(WinGetHandle("[ACTIVE]"))
 EndFunc   ;==>HideCurrentWnd

Func RestoreAllWnd()
	;//Show all windows hidden during this session.
	Local $aTmp = $aHiddenWndList
	For $i = 0 To UBound($aTmp) - 1
		RestoreWnd($aTmp[$i])
	Next
	FileDelete("MTTlog.txt") ;//Lazy way to delete legacy window list in log file.
EndFunc   ;==>RestoreAllWnd


Func CloseWnd()
	ProcessClose(WinGetProcess(WinGetHandle("[ACTIVE]")))
EndFunc   ;==>CloseWnd


Func HandleAltF4()
	If $bAltF4EndProcess = True Then
		CloseWnd()
	Else
		HotKeySet("!{f4}")
		Send("!{f4}")
		HotKeySet("!{f4}", "HandleAltF4")
	EndIf
EndFunc   ;==>HandleAltF4

Func RestoreLastShutdownWindows()
	;//Legacy windows from last run are loaded on startup if available,
	;//this should only happen if MTT was unexpectedly closed while some windows were still hidden.
	$aPrevWndTitleList = FileReadToArray("MTTlog.txt")
	If Not @error Then
		For $i = 0 To UBound($aPrevWndTitleList) - 1
			If StringLen($aPrevWndTitleList[$i]) >= 1 Then
				$hTrayWnd = TrayCreateItem($aPrevWndTitleList[$i] & " - Legacy", -1, 0) ;, $hTrayMenuShowSelectWnd)
				_ArrayAdd($aTrayItemHandles, $hTrayWnd)
				_ArrayAdd($aHiddenWndList, WinGetHandle($aPrevWndTitleList[$i]))
			EndIf
		Next

		If UBound($aTrayItemHandles) Then
			TrayTip("", "You have " & UBound($aTrayItemHandles) & " legacy Window(s) waiting to be restored!", 4)
		EndIf
	EndIf
EndFunc   ;==>RestoreLastShutdownWindows

Func Help()
	MsgBox(64, "ZabbixHidder" & $VERSION, "Pressione [Alt+H] para esconder a janela atual." & @CRLF _
			 & "Pressione [Alt+G] para restaurar a última janela escondida." & @CRLF _
			 & "Janelas escondidas são armazendas no ícone do ZabbixHidder." & @CRLF _
			 & "Se a janela que você quer esconder está sendo executada como administrador, você precisará executar o ZabbixHidder como administrador." & @CRLF & @CRLF _
			 & "brunomeireles23@gmail.com")
EndFunc   ;==>Help


Func ExitS()
	If $bRestoreOnExit Then
		RestoreAllWnd()
	EndIf
	Exit
EndFunc   ;==>ExitS
