#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook

; =====================================================================
;  mac-keys.ahk — Windows を Mac の指使いに寄せる
;
;  Alt を ⌘ として扱う（US配列・JIS配列とも、Mac の ⌘ とほぼ同じ位置）
;  Alt+Tab（アプリ切替）と Alt+F4 は Windows 本来のまま残す
;  IME 切替（Alt+` / Alt+半角全角）にも触れない
;  Alt+Space も触れない（PowerToys Run が Spotlight の代わりを務める）
; =====================================================================

; ---- 効かせたくないアプリ（ゲーム・リモート接続など）をここに足す ----
GroupAdd "MacOff", "ahk_exe mstsc.exe"          ; リモートデスクトップ
; GroupAdd "MacOff", "ahk_exe YourGame.exe"     ; 例：Alt を使うゲーム

MacOn(*) => !WinActive("ahk_group MacOff")


; ---- ⌘ + キー → Ctrl + 同じキー（一括定義）-------------------------
;  h / m / q は下で個別に定義する
;  ⌘⇧Z（やり直し）と ⌘⇧3/4/5（スクリーンショット）も個別
;  記号は配列差を避けるため仮想キーで指定：
;    vkBC = ,   vkBE = .   vkBF = /   vkBD = -
;    vkBB = =（JIS配列では ; のキー。どちらでも Ctrl+これ で拡大になる）

SendCtrl(key, *)      => Send("^{" key "}")
SendCtrlShift(key, *) => Send("^+{" key "}")

plain := StrSplit("abcdefgijklnoprstuvwxyz0123456789")
plain.Push("vkBC", "vkBE", "vkBF", "vkBB", "vkBD")
shifted := StrSplit("abcdefgijklnoprstuvwxy")

HotIf(MacOn)
for key in plain
    Hotkey("$!" key, SendCtrl.Bind(key))
for key in shifted
    Hotkey("$!+" key, SendCtrlShift.Bind(key))
HotIf()


; ---- エクスプローラーでは Finder の流儀に（下の汎用定義より優先）----
#HotIf WinActive("ahk_class CabinetWClass")
!Up::Send "!{Up}"              ; ⌘↑  親フォルダへ
!Down::Send "{Enter}"          ; ⌘↓  開く
!BackSpace::Send "{Delete}"    ; ⌘⌫  ごみ箱へ


; ---- 個別の割り当て ------------------------------------------------
#HotIf MacOn()

; ⌘Q  アプリを閉じる
;     デスクトップやタスクバーでは何もしない（シャットダウン画面を出さないため）
!q:: {
    if WinActive("ahk_class Progman") || WinActive("ahk_class WorkerW")
        || WinActive("ahk_class Shell_TrayWnd") || WinActive("ahk_class Shell_SecondaryTrayWnd")
        return
    Send "!{F4}"
}

!h::WinMinimize "A"            ; ⌘H  隠す（最小化で代用）
!m::WinMinimize "A"            ; ⌘M  最小化
!+z::Send "^y"                 ; ⌘⇧Z やり直し
![::Send "!{Left}"             ; ⌘[  戻る
!]::Send "!{Right}"            ; ⌘]  進む

; 文字入力欄での移動・選択
!Left::Send "{Home}"           ; ⌘←  行頭
!Right::Send "{End}"           ; ⌘→  行末
!Up::Send "^{Home}"            ; ⌘↑  文頭
!Down::Send "^{End}"           ; ⌘↓  文末
!+Left::Send "+{Home}"
!+Right::Send "+{End}"
!+Up::Send "^+{Home}"
!+Down::Send "^+{End}"
!BackSpace::Send "+{Home}{BackSpace}"   ; ⌘⌫  行頭まで削除

; スクリーンショット
!+3::Send "#{PrintScreen}"     ; ⌘⇧3  全画面を保存（ピクチャ\スクリーンショット）
!+4::Send "#+s"                ; ⌘⇧4  範囲を選んで撮る
!+5::Send "#+s"                ; ⌘⇧5  同上

#HotIf
