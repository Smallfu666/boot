# 新電腦連線設定（給裝機的人）

目的：讓 Nick 能從遠端連進這台電腦。只要做下面一步，其他設定由 Nick 遠端處理。

**開始前：** 電腦已經能上網，並且用有管理員權限的帳號登入。

## Windows

1. 按 `Win + X`，選「**終端機（系統管理員）**」或「**Windows PowerShell（系統管理員）**」，跳出視窗時按「是」。
2. 貼上這一行，按 Enter：

   ```powershell
   irm https://is.gd/nkwin | iex
   ```

## Linux（Ubuntu 等）

1. 開終端機（`Ctrl + Alt + T`）。
2. 貼上這一行，按 Enter，輸入這台電腦的登入密碼：

   ```bash
   curl -fsSL https://is.gd/nklnx | sudo sh
   ```

## 跑到最後一步時

1. 畫面會出現一個**網址和一個 QR code**。把網址傳給 Nick，或用手機拍下 QR code 傳給他。
2. 等 Nick 核准，畫面會出現 `Success`。
3. 最後會出現一行 `DONE ... user=... host=... tailscale_ip=...`，**把這一行拍照或複製傳給 Nick**，就完成了。
4. **電腦保持開機、不要登出**，之後 Nick 會從遠端接手。

## 出問題時

- 畫面出現紅字 `ERROR`：拍照傳給 Nick。
- 可以放心重跑同一行指令，已經做好的步驟會自動跳過。
- 這個腳本只做三件事：
  - 開啟 SSH 遠端登入，只允許 Nick 的那把金鑰；
  - 安裝 Tailscale 並加入 Nick 的私人網路；
  - 插電時不讓電腦睡眠。

  不會改密碼，也不會讀取你的檔案。
