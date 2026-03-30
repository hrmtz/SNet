# SNet

[English version](README.md)

**AIを使ってフラッグを取る、CTF。**

ペンテストの経験がなくても大丈夫。Claude Code があなた専属のトレーナーとして、環境構築からツールの使い方、攻撃手法まで一歩ずつガイドします。コマンドを打つのは、全部あなた自身の手です。

## SNet とは？

SNet は、実際に本番稼働していたサーバーをもとに作成した脆弱な仮想マシンです。教科書的な演習ではなく、現実のサーバー管理者が残したカオス — 設定ファイル、放置されたスクリプト、忘れられた認証情報、杜撰な判断の積み重ね — がそのまま再現されています。

攻略ルートは **全10通り**。周回するたびに違うルートを選び、ヒントも減っていきます。全ルートを制覇する頃には、攻撃者と管理者、両方の目を持つようになっているはずです。

ターミナルが開ければ、誰でも遊べます。

## 遊び方

1. **あなたが攻撃、AIがコーチ** — Claude Code は概念の説明や方向性の提案をしますが、キーボードに触るのはあなただけ
2. **リアルなシナリオ** — 作り物のパズルではなく、実際のサーバー設定ミスがベース
3. **10通りの攻略ルート** — 初心者向けから上級者向けまで、ラウンドごとにガイドが減少
4. **攻撃したら、守る** — 脆弱性を突いた後は管理者に立場を変え、自分で穴を塞ぐ
5. **セットアップの手間ゼロ** — コマンド1つ、あとはClaudeが全部やる

## 必要なもの

- [VirtualBox](https://www.virtualbox.org/) 7.0以上
- [Vagrant](https://developer.hashicorp.com/vagrant/install)
- [Anthropic APIキー](https://console.anthropic.com/) または [Claude Max/Proプラン](https://claude.ai)

## セットアップ

```bash
git clone https://github.com/hrmtz/SNet.git
cd SNet
vagrant up
```

全VM（AIトレーナー、Kali、ターゲット）、ネットワーク、ポートフォワード — コマンド1つ。

> **WSL2ユーザー:** VagrantはWindows版ではなく、WSL内にLinux版をインストールしてください。以下の環境変数を設定してください（`~/.bashrc` または `~/.zshrc` に追加）：
>
> ```bash
> export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
> export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"
> ```

> **注意:** `vagrant up` 中にターゲットVMのSSH認証がタイムアウトしますが、これは正常です。ターゲットはCTFマシンのためVagrant SSHを受け付けません。`vagrant status` で `running` と表示されていれば問題ありません。

## 接続方法

| VM | コマンド | 備考 |
|---|---|---|
| AIトレーナー | `vagrant ssh claude` または `ssh -p 2222 snet@localhost` | |
| Kali | `vagrant ssh kali` | |
| ターゲット | ホストからSSH不可 — Kaliから攻撃（`10.0.10.20`） | |

初回ログイン時、Claude Codeが自動起動し認証方法を選択する：

- **APIキー** — Anthropic APIキーを貼り付ける
- **Max/Proプラン** — 「Subscription」を選択し、表示されたURLをブラウザで開いてOAuth認証を完了する

「SNetのセットアップをお願いします」— あとはトレーナーが全部やる。

## サイクル

```
 偵察 → 攻撃 → フラグ奪取
  ↑                  ↓
  ← 管理者として修正 ←
       (× 10 周)
```

1. **user.txt を見つける** — 初期アクセスを獲得する
2. **root.txt を見つける** — root権限まで昇格する
3. **レポートを書く** — 何をやったか、なぜ通ったかを自分の言葉で記録する
4. **穴を塞ぐ** — 攻撃した脆弱性を管理者として修正する
5. **リセットして再挑戦** — 別のルート、少ないヒントで

## シナリオ

このリポジトリは複数のCTFシナリオに対応しています。デフォルトでは `vagrant up` で **SNet1**（初級）が起動します。

| シナリオ | コマンド | 説明 |
|---|---|---|
| SNet1 | `vagrant up` | 鍵のかかっていない家への侵入（初級） |
| [SNet2](SNet2/README.md) | `SNET=2 vagrant up` | 監視の目をかいくぐれ（中級） |

SNet2ではZabbix監視サーバーが追加され、常時監視下での作戦行動が求められます。詳細は [SNet2 README](SNet2/README.md) を参照。

VMが既に起動中の場合、特定のシナリオを追加するには：

```bash
SNET=2 vagrant up snet2-target snet2-zabbix   # SNet2のVMを追加起動
SNET=2 vagrant provision claude                # トレーナーをSNet2用に設定
```

## Tips: リバースシェルの操作性

Kali VMには `rlwrap` と `tmux` がプリインストールされており、リバースシェルの操作が快適になります。

**推奨ワークフロー：**

```bash
# 1. tmuxセッションを起動
tmux new-session -s attack

# 2. rlwrap経由でncを起動（行編集・履歴が使える）
rlwrap nc -lvnp 4444

# 3. tmuxでスクロール: Ctrl+B → [
#    スクロール終了: q
```

**なぜ？** 素のリバースシェルでは矢印キー、Tab補完、スクロールバックが効きません。`rlwrap` はreadlineサポート（履歴・編集）を、`tmux` はスクロールバックとウィンドウ管理を提供します。

## シナリオの更新

新しいシナリオはプロビジョニング時に自動取得されます。最新版を取得するには：

```bash
vagrant provision claude
```

VM全体を再ダウンロードせず、シナリオだけ更新されます。

## ライセンス

本プロジェクトは教育目的でのみ提供されています。責任ある使用をお願いします。
