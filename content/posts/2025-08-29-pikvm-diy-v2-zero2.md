---
title: "Raspberry Pi Zero 2 WでPiKVMを作る"
date: 2025-08-29T19:22:00+09:00
author: Mei Akizuru
slug: pikvm-diy-v2-zero2
tags:
    - tech
    - Raspberry Pi
---

## 背景

[新しいサーバーを組んだ]({{% ref "/posts/2025-03-21-build-new-server.md" %}})で組んだサーバーは基本的にはヘッドレス運用しているわけですが、たまにUEFIセットアップを触りたいときとかにいちいちメインモニターのケーブルを引き回してこないといけないのが地味に不便でした。

（※なぜかUEFIの設定が飛んでマザーボードが†1677万色†で光り始めた場合などに「お前は光らなくてもいいんだぞ」と教え込む必要があります。あちらの記事に記載の通り、どういうわけかモバイルモニターだと表示できないんですよねぇ……）

そこでお手頃にリモートKVMを実現できる[PiKVM](https://pikvm.org/)を試してみました。

## 材料

Raspberry Pi 4を使う場合と異なり電源を分離する必要はないので、Type-CのY字ケーブルとか"Power Splitter"なる謎基板は必要ありません。microUSBケーブルとHDMIケーブルだけは元々家に転がっていたものを使っていて、microSDXCはあきばお〜の並行輸入品、それ以外はすべて秋葉原の千石電商で揃えています。

|                                                商品                                                 | 価格（円） |
| --------------------------------------------------------------------------------------------------- | ---------: |
| Raspberry Pi Zero 2 WH (SC0721)                                                                     |       4300 |
| KSY Raspberry Pi 3 / Zero 2 W 対応電源 USB電源アダプター 5V/3A 1.5m microUSBコネクター (UU318-0530) |       1650 |
| WaveShare 【11944】 Raspberry Pi Zero V1.3 Camera Cable 15cm                                        |        550 |
| WaveShare 【19137】 Raspberry Piシリーズ用HDMI-CSIアダプタ                                          |       4380 |
| WaveShare 【23027】 Raspberry Pi Zero/Zero2W用アルミケース（ヒートシンク機能付）                    |       1180 |
| Adafruit PiOLED (ADA-3527)                                                                          |       2300 |
| SanDisk Extreme microSDXC 64GB SDSQXAH-064G-GN6MN                                                   |        940 |
| HDMIケーブル                                                                                        |            |
| USB Type-A to micro-B ケーブル                                                                      |            |
| 合計                                                                                                |      15300 |

ちなみにRaspberry Pi 4を使う場合は2GBモデルで良いとされていますが、それでも11,000円するのでトータルコストはお察し下さい。ちなみにPiKVM公式としては「Zero 2は安くて小さいが無線LANしかないので信頼性に欠ける」と言っていて、推奨はPi4 2GBとしています。

なお、以下の作業における作業マシンはMacBook Pro (M1 Max)、KVMで接続する先（ホストマシン）はUbuntu 24.04 LTSが動作しているサーバー機です。

## OSの準備

PiKVM公式から"DIY PiKVM V2 Platform"で"Raspberry Pi Zero 2 W"向けのイメージを探します。執筆時点では"For HDMI-CSI bridge"のみになっているので、このイメージをダウンロードします。サーバーが重いのかなかなか時間がかかりました。

ダウンロードできたらRaspberry Pi Imagerで書き込みます。カスタムイメージを書くのでデバイスは"No filtering"として、イメージ選択でカスタムイメージを選択してダウンロードしてきた`.img.xz`ファイルを選択します。microSDを挿して書き込み先を選び書き込みます。書き込む際にホスト名やWiFiの設定なんかを書き込むかを聞かれますが、PiKVM用のOSはImagerでのカスタムが正常に機能しないので拒否します。

書き込みが終了したら自動で取り出されますが、設定を書く必要があるので挿し直します。ブートパーティションはFAT32なので普通にマウントされるはずです。カード内に`FIRST_BOOT=1`と書かれている`pikvm.txt`があります。

```console
$ ls
 bcm2708-rpi-b-plus.dtb   bcm2709-rpi-2-b.dtb        bcm2710-rpi-zero-2-w.dtb   bcm2711-rpi-cm4s.dtb     bcm2835-rpi-cm1-io1.dtb    bcm2837-rpi-3-b.dtb        fixup.dat      fixup_db.dat          start.elf      start_db.elf
 bcm2708-rpi-b-rev1.dtb   bcm2709-rpi-cm2.dtb        bcm2710-rpi-zero-2.dtb     bcm2835-rpi-a-plus.dtb   bcm2835-rpi-zero-w.dtb     bcm2837-rpi-cm3-io3.dtb    fixup4.dat     fixup_x.dat           start4.elf     start_x.elf
 bcm2708-rpi-b.dtb        bcm2710-rpi-2-b.dtb        bcm2711-rpi-4-b.dtb        bcm2835-rpi-a.dtb        bcm2835-rpi-zero.dtb       bcm2837-rpi-zero-2-w.dtb   fixup4cd.dat   initramfs-linux.img   start4cd.elf
 bcm2708-rpi-cm.dtb       bcm2710-rpi-3-b-plus.dtb   bcm2711-rpi-400.dtb        bcm2835-rpi-b-plus.dtb   bcm2836-rpi-2-b.dtb        bootcode.bin               fixup4db.dat   kernel7.img           start4db.elf
 bcm2708-rpi-zero-w.dtb   bcm2710-rpi-3-b.dtb        bcm2711-rpi-cm4-io.dtb     bcm2835-rpi-b-rev2.dtb   bcm2837-rpi-3-a-plus.dtb   cmdline.txt                fixup4x.dat    overlays              start4x.elf
 bcm2708-rpi-zero.dtb     bcm2710-rpi-cm3.dtb        bcm2711-rpi-cm4.dtb        bcm2835-rpi-b.dtb        bcm2837-rpi-3-b-plus.dtb   config.txt                 fixup_cd.dat   pikvm.txt             start_cd.elf

$ cat pikvm.txt
FIRST_BOOT=1
```

この`FIRST_BOOT=1`は残しておいて、次の内容を追記します。保存したらカードを取り出します。

```bash
FIRST_BOOT=1
WIFI_ESSID='ssid'
WIFI_PASSWD='password'
WIFI_REGDOM=JP
WIFI_ADDR=192.168.0.100/24
WIFI_DNS=192.168.0.1
WIFI_GW=192.168.0.1
```

設定している内容は次の通りです。

* 接続先のWiFiの設定（SSIDとパスワード）
* WiFiの規制ドメイン設定（Zero2だと2.4GHzしか繋がらないんであんま関係無いかもだけど一応）
* WiFi I/FのIPアドレス、DNS、デフォルトゲートウェイの設定（これを省くとDHCPで自動設定されるが、自動設定されたIPアドレスを知る手段がない）
  * 今回は`192.168.0.100`にしたとして説明

DHCPを使ったとしても、セットアップの時だけ画面とキーボード繋いでみるなりARP探ってみるなりポートスキャンするなりでやりようはありますが、まぁ面倒なので固定しちゃった方が楽でしょう。……ところでOLED買ってなかったかって？　セットアップ中はまだ有効化されてないので使えません。

## 物理配線

HDMI-CSIアダプタを接続します。今回買ったアダプタにはカメラケーブルが付属していましたが、ZeroでないRaspberry Pi用なので使えません（一瞬カメラケーブルを別に買ったのは余計だったかと思って若干焦った）。Raspberry Pi Zero 2側は黒い部分を水平に引き出してから差し込んで戻す、アダプタ側は黒い部分を上に持ち上げてから差し込んで戻します。

（ところでこのカメラケーブル、明らかに15cmもいらないなと思ってたらスイッチサイエンスに[短めのRaspberry Pi Zero用カメラケーブル](https://ssci.to/8939)なるものがありました。Amazonにも似たような商品が出品されているようです。しかし、「公式ケースに付属しているものと同じ」ということはこの家のどこかにも転がっている気がする……）

CSIケーブルを繋いだところでケースに入れました（入れるというか挟み込むタイプなので入れる感はありませんが）。その後OLEDを接続します。PiOLEDはI2C接続で、GPIOポートのうちmicroSDカードスロット寄りの2x3=6本を占有します。

USBは公式のハンドブックにも記載がありますが、ケーブルに一工夫が必要です。Zero 2には2つのmicroB端子がありますが、CSIコネクタ寄りにある方が"PWR"で、その隣が"USB"となっています（Zero 2の基板にも記載があります）。で、説明によればこの2つは電源線を共有しているので、"USB"の方から電源供給されてしまうと困った事態になります。そこで、"USB"に繋ぐ方のUSBケーブルのホスト側(Type-A)端子のうち、電源ピン(VBUS)の部分にテープを貼って絶縁します。樹脂部分を下にしたときの一番右のピンですが、ハンドブックの写真や、ピンアサインを検索して確認してください。

ちなみにZero 2くらいの電力だとホストPCからの供給でも普通に動きそうなものですが、その場合ホストの電源が落ちているとPiKVMも落ちてしまい、UEFIセットアップに入るのが現実的でなくなります。

HDMIケーブルは普通にアダプタの端子とPCの出力端子を接続します。

最後に"PWR"のポートに電源アダプタのmicroBケーブルを接続し、コンセントにアダプタを接続します。これでZero 2の電源が入りますが、初回起動時はセットアップ処理で少し起動に時間がかかるので、終わるまで電源を落とさないようにします。

## 初期設定

今回は`pikvm.txt`でIPアドレスを固定したので、特にPiKVMを探す必要はなく`https://192.168.0.100`にブラウザからアクセスすればOKです。証明書の警告が出ますが続行します。PiKVMのログイン画面が出るので、`admin:admin`（2FAは省略）でログインします。

まずはパスワードを変更します。

1. rootになる（デフォルトのrootパスワードは`root`）
2. ファイルシステムを読み書きモードで再マウント
3. rootパスワードを変更
4. 管理画面のadminアカウントのパスワードを変更

```console
[kvmd-webterm@pikvm ~]$ su -
Password:
[root@pikvm ~]# rw
+ mount -o remount,rw /
+ mount -o remount,rw /boot
+ set +x
=== PiKVM is in Read-Write mode ===
[root@pikvm ~]# passwd root
New password:
Retype new password:
passwd: password updated successfully
[root@pikvm ~]# kvmd-htpasswd set admin
Password:
Repeat:

# Note: Users logged in with this username will stay logged in.
# To invalidate their cookies you need to restart kvmd & kvmd-nginx:
#    systemctl restart kvmd kvmd-nginx
# Be careful, this will break your connection to the PiKVM
# and may affect the GPIO relays state. Also don't forget to edit
# the files /etc/kvmd/{vncpasswd,ipmipasswd} and restart
# the corresponding services kvmd-vnc & kvmd-ipmi if necessary.
[root@pikvm ~]# ro
+ mount -o remount,ro /
+ mount -o remount,ro /boot
+ set +x
=== PiKVM is in Read-Only mode ===
[root@pikvm ~]# exit
logout
```

PiKVMのOSのrootパスワードと、PiKVMの管理UIのadminアカウントのパスワードは連動していないので、個別に変更が必要です。

PiKVM OSの特徴的な点として、ファイルシステムがデフォルトで読み取り専用(`ro`)モードになっている点があります。そのため、パスワード変更やOSの設定変更など、ファイルシステムに書き込む必要がある場合には明示的に読み書き(`rw`)モードで再マウントしなくてはなりません。root状態で`rw`とすれば読み書きモードになり、`ro`とすれば読み取り専用モードに戻ります。

Terminalでは`exit`を叩いてもすぐに再接続されるので、ブラウザの戻るボタンで最初の画面に戻ります。

## リモートKVMの動作確認

ログイン後の画面で"KVM"を選択すればリモートKVMとして使えます。"KVM"を選んでからサーバーの電源を入れるとUEFIのスプラッシュスクリーンから見ることができます。ヤッター！　当然ここでDeleteを連打すればセットアップにも入れます。

Ubuntuが入っているサーバーなので、ログインした後にディスプレイの設定を見てみるとこんな感じでした。デフォルトだと1280x720@60Hzに設定されています。PiKVM V2 DIYの場合は1920x1080@50Hzが最大になりますが、この設定だとたまに画面にノイズが走っていました。デフォルトの1280x720@60Hzで運用する方が良いでしょう。

{{< fluid_imgs "pure-u|/images/2025-08-28-pikvm-ubuntu-display-setting.jpg|Ubuntu Display Settings" >}}

あと再起動するとKVMの画面が戻ってきませんでした。たまたまなのか、別の問題があるのかは確認してません。

## OSのメンテナンス

PiKVM OSそれ自体のメンテナンスもしましょう。というわけでまずはアップデートが推奨されています。rootでログインしてアップデートをかけます。

```console
[root@pikvm ~]# pikvm-update
+ trap on_error ERR
+ _yes='--noconfirm --ask=4 --overwrite \*'
+ rw
+ mount -o remount,rw /
+ mount -o remount,rw /boot
+ set +x
=== PiKVM is in Read-Write mode ===
+ pacman -Syy
...
```

ログを見るとわかるようにPiKVM OSはArch Linuxがベースなのでパッケージ管理はpacmanで行われています。`pacman -Syu`で全てを破壊したあの頃が懐かしい。しばらくかかるので放置します。

## 謎のトラブル発生

で、なんか様子が変でした。

```console
...
(14/18) Updating linux initcpios...
double free or corruption (!prev)
error: unable to write to pipe (Broken pipe)
error: command terminated by signal 6: Aborted
(15/18) Reloading system bus configuration...
double free or corruption (!prev)
error: command terminated by signal 6: Aborted
(16/18) Checking for old perl modules...
double free or corruption (!prev)
error: command terminated by signal 6: Aborted
(17/18) Compiling GSettings XML schema files...
double free or corruption (!prev)
error: command terminated by signal 6: Aborted
(18/18) Updating the info directory file...
double free or corruption (!prev)
error: command terminated by signal 6: Aborted
double free or corruption (!prev)
/usr/bin/pikvm-update: line 108:  3382 Aborted                 (core dumped) pacman $_yes -Su
++ on_error
++ set +x
==============================================================
      An unexpected error occurred during the update.
==============================================================

==============================================================
Please note that the filesystem now remain in Read-Write mode.
       A reboot is necessary to make it Read-Only again.
The reboot can be performed later using the 'reboot' command.
==============================================================
++ set -x
++ on_error
++ set +x
==============================================================
      An unexpected error occurred during the update.
==============================================================

==============================================================
Please note that the filesystem now remain in Read-Write mode.
       A reboot is necessary to make it Read-Only again.
The reboot can be performed later using the 'reboot' command.
==============================================================
++ set -x
```

あからさまに怪しいログが出ました。`rw`モードのままになっていて再起動しないと`ro`モードにならない、ということでとりあえず再起動してみたところ、戻ってこなくなりました。pacmanやってシステムを破壊するのは気持ちが良いですね〜（pacmanのせいじゃなさそうだけど……）。

ログを遡ってみると、更新のチェックやパッケージ取得までは特に異常はないのですが、pre-transaction hooksのところからなんだか怪しげでした。

```console
...
(210/210) checking keys in keyring                                                                                                                                 [####################################################################################################] 100%
(210/210) checking package integrity                                                                                                                               [####################################################################################################] 100%
(210/210) loading package files                                                                                                                                    [####################################################################################################] 100%
(210/210) checking for file conflicts                                                                                                                              [####################################################################################################] 100%
(210/210) checking available disk space                                                                                                                            [####################################################################################################] 100%
warning: could not get file information for var/log/old/
warning: could not get file information for var/log/journal/
warning: could not get file information for var/log/nginx/
:: Running pre-transaction hooks...
(1/2) Removing linux initcpios...
double free or corruption (!prev)
error: command terminated by signal 6: Aborted
(2/2) Removing old entries from the info directory file...
double free or corruption (!prev)
error: command terminated by signal 6: Aborted
:: Processing package changes...
(  1/210) upgrading alsa-ucm-conf                                                                                                                                  [####################################################################################################] 100%
(  2/210) upgrading tzdata                                                                                                                                         [####################################################################################################] 100%
(  3/210) upgrading iana-etc                                                                                                                                       [####################################################################################################] 100%
(  4/210) upgrading filesystem                                                                                                                                     [####################################################################################################] 100%
(  5/210) upgrading alsa-lib                                                                                                                                       [####################################################################################################] 100%
double free or corruption (!prev)
error: command terminated by signal 6: Aborted
(  6/210) upgrading ncurses                                                                                                                                        [####################################################################################################] 100%
...
```

明らかに何かを破壊していそうな予感がします。ただストレージの問題という可能性もあるので、念のためMacに挿して再フォーマット、f3でチェックしたところ、そちらでは問題を確認できませんでした。

```console
arm64 ~ via 💎 v3.3.5 via 🆂
❯ f3write /Volumes/NO\ NAME
F3 write 9.0
Copyright (C) 2010 Digirati Internet LTDA.
This is free software; see the source for copying conditions.

Free space: 59.45 GB
Creating file 1.h2w ... OK!
Creating file 2.h2w ... OK!
...
Creating file 59.h2w ... OK!
Creating file 60.h2w ... OK!
Free space: 256.00 KB
Average writing speed: 69.76 MB/s

arm64 ~ via 💎 v3.3.5 via 🆂 took 14m33s884ms
❯ f3read /Volumes/NO\ NAME
F3 read 9.0
Copyright (C) 2010 Digirati Internet LTDA.
This is free software; see the source for copying conditions.

                  SECTORS      ok/corrupted/changed/overwritten
Validating file 1.h2w ... 2097152/        0/      0/      0
Validating file 2.h2w ... 2097152/        0/      0/      0
...
Validating file 59.h2w ... 2097152/        0/      0/      0
Validating file 60.h2w ...  932772/        0/      0/      0

  Data OK: 59.44 GB (124664740 sectors)
Data LOST: 0.00 Byte (0 sectors)
	       Corrupted: 0.00 Byte (0 sectors)
	Slightly changed: 0.00 Byte (0 sectors)
	     Overwritten: 0.00 Byte (0 sectors)
Average reading speed: 91.22 MB/s
```

ついでにRead 91.22 MB/s、Write 69.76 MB/sということで、それぞれスペック表記の104 MB/s（これはUHS-Iの理論値。パッケージには170 MB/sとあるけど、それは専用のリーダーが必要）、80 MB/sからそう派手に落ちてないことがわかりました。

改めて焼き直して様子を見ます。`pikvm.txt`の編集をしてから起動して、パスワード変更後に`pikvm-update`を実行しました。

```console
# pikvm-update
+ trap on_error ERR
+ _yes='--noconfirm --ask=4 --overwrite \*'
+ rw
+ mount -o remount,rw /
+ mount -o remount,rw /boot
+ set +x
=== PiKVM is in Read-Write mode ===
+ pacman -Syy
:: Synchronizing package databases...
 core                                                                                                                                  242.7 KiB  81.2 KiB/s 00:03 [####################################################################################################] 100%
 extra                                                                                                                                   9.4 MiB  2.08 MiB/s 00:05 [####################################################################################################] 100%
 community                                                                                                                              45.0   B   125   B/s 00:00 [####################################################################################################] 100%
 alarm                                                                                                                                  94.9 KiB   127 KiB/s 00:01 [####################################################################################################] 100%
 aur                                                                                                                                    10.3 KiB  27.1 KiB/s 00:00 [####################################################################################################] 100%
 pikvm                                                                                                                                  13.8 KiB  9.61 KiB/s 00:01 [####################################################################################################] 100%
++ pacman -S -u --print-format %n
++ grep -v pikvm-os-updater
++ wc -l
+ '[' 210 -eq 0 ']'
+ rm -rf /var/cache/pacman/pkg
+ mkdir -p /var/cache/pacman/pkg
+ '[' -z '' ']'
++ pacman -S --needed --print-format %n pikvm-os-updater
++ wc -l
+ '[' 1 -ne 0 ']'
+ pacman --noconfirm --ask=4 --overwrite '\*' -S pikvm-os-updater
resolving dependencies...
looking for conflicting packages...

Packages (1) pikvm-os-updater-0.30-1

Total Download Size:   0.00 MiB
Total Installed Size:  0.00 MiB
Net Upgrade Size:      0.00 MiB

:: Proceed with installation? [Y/n]
:: Retrieving packages...
 pikvm-os-updater-0.30-1-any                                                                                                             4.3 KiB  5.22 KiB/s 00:01 [####################################################################################################] 100%
(1/1) checking keys in keyring                                                                                                                                     [####################################################################################################] 100%
(1/1) checking package integrity                                                                                                                                   [####################################################################################################] 100%
(1/1) loading package files                                                                                                                                        [####################################################################################################] 100%
(1/1) checking for file conflicts                                                                                                                                  [####################################################################################################] 100%
(1/1) checking available disk space                                                                                                                                [####################################################################################################] 100%
:: Processing package changes...
(1/1) upgrading pikvm-os-updater                                                                                                                                   [####################################################################################################] 100%
:: Running post-transaction hooks...
(1/1) Arming ConditionNeedsUpdate...
+ _opts=--no-self-update
+ '[' -n '' ']'
+ pikvm-update --no-self-update
+ trap on_error ERR
+ _yes='--noconfirm --ask=4 --overwrite \*'
+ rw
+ mount -o remount,rw /
+ mount -o remount,rw /boot
+ set +x
=== PiKVM is in Read-Write mode ===
+ pacman -Syy

...

(210/210) upgrading wireless-regdb                                                                                                                                 [####################################################################################################] 100%
:: Running post-transaction hooks...
( 1/18) Creating system user accounts...
( 2/18) Updating journal message catalog...
( 3/18) Reloading system manager configuration...
( 4/18) Reloading user manager configuration...
( 5/18) Updating udev hardware database...
( 6/18) Restarting marked services...
( 7/18) Applying kernel sysctl settings...
( 8/18) Creating temporary files...
( 9/18) Reloading device manager configuration...
(10/18) Arming ConditionNeedsUpdate...
(11/18) Rebuilding certificate stores...
(12/18) Updating module dependencies...
(13/18) Restart a running sshd.service
(14/18) Updating linux initcpios...
==> Building image from preset: /etc/mkinitcpio.d/linux-rpi.preset: 'default'
==> Using default configuration file: '/etc/mkinitcpio.conf'
  -> -k 6.6.45-13-rpi -g /boot/initramfs-linux.img
==> Starting build: '6.6.45-13-rpi'
  -> Running build hook: [base]
  -> Running build hook: [udev]
  -> Running build hook: [block]
  -> Running build hook: [filesystems]
  -> Running build hook: [rootdelay]
==> Generating module dependencies
==> Creating gzip-compressed initcpio image: '/boot/initramfs-linux.img'
  -> Early uncompressed CPIO image generation successful
==> Initcpio image generation successful
(15/18) Reloading system bus configuration...
(16/18) Checking for old perl modules...
(17/18) Compiling GSettings XML schema files...
(18/18) Updating the info directory file...
+ systemctl is-enabled -q tailscaled
+ kvmd -m
+ '[' -n '' ']'
+ '[' -z '' ']'
+ set +x
==============================================================
      Reboot required. We will make it after 30 seconds.
            Press Ctrl+C if you don't want this.
==============================================================

==============================================================
Please note that the filesystem now remain in Read-Write mode.
       A reboot is necessary to make it Read-Only again.
The reboot can be performed later using the 'reboot' command.
==============================================================
+ set -x
+ sleep 30
```

何の問題もなく完了しました。なんだったんだろう……。

## 細かい設定

気を取り直して細々とした設定を済ませていきます。設定を弄る際には読み書きモードにするのを忘れずに。

```console
# rw
```

### 時刻設定

2FAを有効にするためにも時刻は正確である必要があります……が、ArchデフォルトのNTPサーバーへ問い合わせるようになっているので、すっ飛ばしてもたぶん大丈夫です。

タイムゾーンを東京に変更します。ちなみに2FAの時刻同期にタイムゾーンは関係ないです。

```console
# timedatectl set-timezone Asia/Tokyo
```

NTPサーバーは前述のようにディストリビューションのデフォルトが設定されていますが、NICTのNTPサーバーを設定してみます。`/etc/systemd/timesyncd.conf`の`NTP=`の行を有効にして`ntp.nict.jp`を設定します。

```console
# vi /etc/systemd/timesyncd.conf
```

```ini
[Time]
NTP=ntp.nict.jp
# ...
```

一応サービスを再起動してから状態を確認します。

```console
# systemd restart systemd-timesyncd
# timedatectl status
               Local time: Fri 2025-08-29 04:13:31 JST
           Universal time: Thu 2025-08-28 19:13:31 UTC
                 RTC time: n/a
                Time zone: Asia/Tokyo (JST, +0900)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
# timedatectl show-timesync
LinkNTPServers=2404:1a8:1102::b 2404:1a8:1102::a
SystemNTPServers=ntp.nict.jp
FallbackNTPServers=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org 3.arch.pool.ntp.org
ServerName=2404:1a8:1102::b
ServerAddress=2404:1a8:1102::b
RootDistanceMaxUSec=5s
PollIntervalMinUSec=32s
PollIntervalMaxUSec=34min 8s
PollIntervalUSec=4min 16s
NTPMessage={ Leap=0, Version=4, Mode=4, Stratum=2, Precision=-18, RootDelay=4.913ms, RootDispersion=991us, Reference=85F3EC12, OriginateTimestamp=Fri 2025-08-29 04:31:23 JST, ReceiveTimestamp=Fri 2025-08-29 04:31:23 JST, TransmitTimestamp=Fri 2025-08-29 04:31:23 JST, DestinationTimestamp=Fri 2025-08-29 04:31:23 JST, Ignored=no, PacketCount=6, Jitter=24.303ms }
Frequency=-87554
```

設定はしてみたものの、`ServerAddress`を見ると`2404:1a8:1102::b`になっているので、どうやらIPv6のDHCPで降ってきたNGN内にいるNTT東日本のサーバーを見ているらしい。まぁ時刻が正しいならヨシ！

（※みんな大好きArchWikiの[systemd-timesyncd](https://wiki.archlinux.jp/index.php/Systemd-timesyncd)によれば、NTPサーバーの優先順位はDHCPで来たやつ→`timesyncd.conf`の設定→`FallbackNTP`という順番らしいので、DHCPで降ってきたサーバーが優先されているようです）

### 2FAの有効化

```console
# kvmd-totp init
```

コンソールにQRコードが表示されたのでビビり散らかしました。Google Authenticatorなり何なりでQRコードを読み取れば設定完了です。URIも表示されるので、QRコードが読めなくても安心です。次回以降のログインからフォームの2FAの項目に入力してログインします。一般的なサイトでよくある初期設定での確認等はない点には注意しましょう。

### ユーザーの追加

OSのユーザーというのは標準状態だとrootと"Terminal"でつないだときにログインする`kvmd-webterm`ユーザーしかいないわけですが、PiKVMのメンテナンスのためにいちいちブラウザ使うのもまどろっこしいのでSSHを使いたいところ。当然rootでSSHしてもよいのですが、自前のユーザーを使って公開鍵認証をする方が安全でしょう。

```console
[root@pikvm ~]# useradd -m -G wheel -s /bin/bash -U hoge
[root@pikvm ~]# su hoge

[hoge@pikvm root]$ cd
[hoge@pikvm ~]$ mkdir .ssh
[hoge@pikvm ~]$ chmod 700 .ssh
[hoge@pikvm ~]$ echo 'SSH_PUBLIC_KEY' >> .ssh/authorized_keys
[hoge@pikvm ~]$ chmod 600 .ssh/authorized_keys
[hoge@pikvm ~]$ exit
```

ちなみに`wheel`に所属させてみたものの、sudoers見たら`wheel`に対してsudoを許可する設定が無効のままなので、`wheel`に所属させただけではsudoができません。でもまぁ`su -`すればいいからいっか……ということで放置してます。安全にしたいのかなんなのか。

### OLEDを有効にする

[PiKVM DIY v2 … Raspberry Pi Zero 2 WでKVM over IP | PRO'LOGUE](https://ryo.net/?p=13164)を参考に設定を弄りました。

まず設定を編集します。いずれも1行追記します。

```console
# echo 'dtparam=i2c_arm=on' >> /boot/config.txt
# echo 'i2c-dev' >> /etc/modules-load.d/kvmd.conf
```

サービスを有効にします。参考記事にある通り、この時点では上で書いた設定がまだ効いてないのでエラーになります。

```console
# systemctl enable --now kvmd-oled kvmd-oled-reboot kvmd-oled-shutdown
Job for kvmd-oled-shutdown.service failed because a fatal signal was delivered to the control process.
See "systemctl status kvmd-oled-shutdown.service" and "journalctl -xeu kvmd-oled-shutdown.service" for details.
Job for kvmd-oled-reboot.service failed because a fatal signal was delivered to the control process.
See "systemctl status kvmd-oled-reboot.service" and "journalctl -xeu kvmd-oled-reboot.service" for details.
```

### その他雑多なもの

ホスト名を設定します。

```console
# hostnamectl set-hostname pikvm.example.com
```

我が家ではRTX1210でDNSサーバーが動いているので、この名前で`192.168.0.100`に名前解決できるようにこんな感じの設定を追加しました。

```plain
ip host pikvm.example.com 192.168.0.100 ttl=300
```

最後に再起動します。

```console
# reboot
```

再起動したらOLEDに情報が表示されるようになりました。ヤッタネ！　眺めていると温度が42.9℃と表示されていました。結構アチアチになるんですね。

## おわりに

というわけで無事にRaspberry Pi Zero 2 WHでPiKVM V2 DIYが完成しました。トータルで1.5万円くらいでこれが仕上がるのは結構良いのではないでしょうか。PiKVM自体がそんなにリソース食うことはないっぽいので4B 2GB使うよりも手軽です。

ATX電源制御もできるっぽいんですが、さすがにフォトカプラやらなんやら用意してーってのは面倒だったのでやりませんでした。暇があったらやってみたいですね。いやこれ書いてるときちょうどサバティカル休暇中で暇ではあるんですがこう、違うんですよ。

あとTailscale VPNに対応していて、簡単な手順で外からアクセスできるようにセットアップできますが、そちらもやってません。ドキュメントにはあるけど非公式の手順としてCloudflare Tunnelを使う場合も紹介されています。今ちょうどCloudflare Tunnel使ってるので、こちらも後ほど試してみようかなと思っています。

また、無線LANしかないという問題に関しては、まぁ現代の宅内で使うならそこまで問題でもないような気がしますが、どうしても有線LANが良いのであればRJ45端子を積んでいるHATを乗せる手があります。それだけだと線が1本増えますが、[公式のFAQ](https://docs.pikvm.org/faq/)によればPoEでも動くとのことなのでPoE使うのも良いかなと思います。PoE使う場合もやっぱり電源線の問題があるので、通常の手順同様にデータ用のUSBケーブルから給電されないように弄る必要がありそうです。

## 参考にした記事

本稿内でリンクを貼った以外に参考にした先人の記事

* [PiKVMのインストール #Linux - Qiita](https://qiita.com/naosone/items/dbbfe7989063ed13a2fb)
