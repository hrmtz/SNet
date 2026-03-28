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
5. **セットアップの手間ゼロ** — OVAをインポートしてSSHするだけ、あとはClaudeが全部やる

## 必要なもの

- [VirtualBox](https://www.virtualbox.org/) 7.0以上
- Kali Linux VM（[kali.org](https://www.kali.org/get-kali/#kali-virtual-machines)）

## ダウンロード

[Releases](https://github.com/hrmtz/SNet/releases)からダウンロード：

| OVA | 説明 |
|-----|------|
| `SNet1.ova` | ターゲットVM（攻撃対象のサーバー） |

ターゲットVMだけで遊べる。Kaliを用意して、あとはやるだけ。

### オプション：AIトレーナー

CTFをコーチしてくれるAIトレーナー（Claude Code）。ツールの解説、方向性の提案、スキルレベルに合わせたガイド。経験者でもゲーム体験が変わる。

| | 必要なもの | RAM |
|-|-----------|-----|
| **サンドボックス**（推奨） | [`SNet-Claude.ova`](https://github.com/hrmtz/SNet/releases) + [APIキー](https://console.anthropic.com/) | 8GB+ |
| **ローカル** | このリポジトリを`git clone` + [Claude Code](https://www.npmjs.com/package/@anthropic-ai/claude-code) + [APIキー](https://console.anthropic.com/) | 6GB+ |

## セットアップ

### Target + Kali のみ

`SNet1.ova`をVirtualBoxにインポート。KaliとTargetのネットワークを設定。あとは攻撃あるのみ。

### AIトレーナー付き（サンドボックス）

トレーナーは専用VMで動く — ホストには何もインストールしない。

1. `SNet-Claude.ova`と`SNet1.ova`をVirtualBoxにインポート
2. ネットワーク作成（初回のみ）：

```bash
VBoxManage natnetwork add --netname "SNet-Net" --network "10.0.1.0/24" --enable --dhcp on
VBoxManage natnetwork modify --netname "SNet-Net" --port-forward-4 "claude-ssh:tcp:[]:2222:[10.0.1.5]:22"
VBoxManage natnetwork modify --netname "SNet-Net" --port-forward-4 "kali-ssh:tcp:[]:2223:[10.0.1.10]:22"
```

3. 全VM起動：

```bash
VBoxManage startvm "SNet-Claude" --type headless
VBoxManage startvm "SNet-Kali" --type headless
```

4. トレーナーに接続：

```bash
ssh -p 2222 snet@localhost
```

デフォルトパスワード: `snet`。初回ログイン時にAnthropic APIキーを入力。Claude Codeが自動起動する。

5. 「SNetのセットアップをお願いします」— あとはトレーナーが全部やる。

### AIトレーナー付き（ローカル）

```bash
git clone https://github.com/hrmtz/SNet.git
cd SNet
npm install -g @anthropic-ai/claude-code
export ANTHROPIC_API_KEY="sk-ant-..."
claude
```

KaliとTargetのVMはVirtualBoxで起動しておくこと。

### Vagrantで一発

```bash
git clone https://github.com/hrmtz/SNet.git
cd SNet
vagrant up
```

全VM、ネットワーク、ポートフォワード — コマンド1つ。`vagrant ssh claude`または`ssh -p 2222 snet@localhost`で接続。

### セットアップが難しい？

VBoxManageコマンドやNATネットワーク設定が面倒なら、ホストマシンのClaude Codeに任せられる。適当なディレクトリで`claude`を起動して、これを貼り付けるだけ：

> SNet1.ovaとSNet-Claude.ovaをダウンロードしました。VirtualBoxにインポートして、SNet-Net（10.0.1.0/24）というNATネットワークを作成し、SSHのポートフォワード（ホスト2222→10.0.1.5:22、ホスト2223→10.0.1.10:22）を設定して、全VMを起動してください。

ホスト上のClaude Codeは通常の権限で動作する — コマンド実行前に毎回確認が入る。`CLAUDE.md`の広い権限はトレーナーがKaliにSSHしてセットアップスクリプトを実行するためだけに存在する。セットアップ完了後、それらの権限は不要になる。

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

## セキュリティについて

このリポジトリにはネタバレ防止のため暗号化されたファイルがあります。暗号化されたファイルの実行に抵抗がある場合は、サンドボックスのOVA内で実行してください — そのためのOVAです。

## ファイル一覧

| ファイル | 説明 |
|---|---|
| `SNet1.ova` | ターゲットVM |
| `SNet-Claude.ova` | AIトレーナーVM（Claude Code） |
| `claude.md.enc` | AIトレーナー設定（自動で読み込まれる） |
| `install.sh.enc` | Kali VMセットアップスクリプト（自動実行） |
| `CLAUDE.md` | AIトレーナー用セットアップ手順 |

## ライセンス

本プロジェクトは教育目的でのみ提供されています。責任ある使用をお願いします。
