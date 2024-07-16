---
title: "Raspberry Pi 5 w/ Argon ONE V3 & NVMe SSD"
date: 2024-07-16T21:50:00+09:00
author: Mei Akizuru
slug: rpi5-argon-one-v3-nvme-ssd
tags:
    - tech
    - Raspberry Pi
---

## 概要

Raspberry Pi 5が（3月くらいに）届いてたので適当にセットアップした記録。——を書いて力尽きていたのを7月に入って続きを書き始めた記事です。

同じような記事は山ほどあるだろうけど……。

## 買ったもの

* Raspberry Pi 5 8GB: [KSY](https://raspberry-pi.ksyic.com/main/index)で購入
* Raspberry Pi 5用公式ケース（黒）: 同上
* SanDisk Ultra 128GB (microSD): 秋葉原のあきばお〜で購入
* [Argon ONE V3 M.2 NVME PCIE Case](https://argon40.com/products/argon-one-v3-m-2-nvme-case): ほったらかしてる間に千石電商で取り扱いが始まってたので買ってみた
* Western Digital WD Blue SN580 1TB: いつだかの東京都のQRコード決済キャンペーンの時に駆け込みで買ったSSD

今回買ったものではありませんが、電源は5V4Aを供給できる[TSI-PI046-5V4A](https://www.sengoku.co.jp/mod/sgk_cart/detail.php?code=EEHD-5RTU)を（Raspberry Pi 4から使い回して）使用しています。

## SDカードのチェック

届いた直後の動作確認で使用したのは秋葉原のあきばお〜で購入したSanDisk Ultra 128GBでした。念のため[F3](https://fight-flash-fraud.readthedocs.io/en/latest/)でSDカードをチェックしておきます。

TS3 PlusのスロットにmicroSDを差し込み、まず正常に認識されることを確認し、さらにディスクユーティリティからex-FATでのフォーマットを実行しました。ここまで正常に完了したところで、まずは`f3write`で書き込みテストをします。フォーマット時に名前を`Untitled`のままにしたので、テスト対象は`/Volumes/Untitled`です。

```
❯ f3write /Volumes/Untitled
F3 write 8.0
Copyright (C) 2010 Digirati Internet LTDA.
This is free software; see the source for copying conditions.

Free space: 118.94 GB
Creating file 1.h2w ... OK!
...
Creating file 119.h2w ... OK!
Free space: 640.00 KB
Average writing speed: 30.56 MB/s
```

所要時間は1時間ちょっと。続けて`f3read`で読み取りテストをします。

```
❯ f3read /Volumes/Untitled
F3 read 8.0
Copyright (C) 2010 Digirati Internet LTDA.
This is free software; see the source for copying conditions.

                  SECTORS      ok/corrupted/changed/overwritten
Validating file 1.h2w ... 2097152/        0/      0/      0
...
Validating file 119.h2w ... 1960761/        0/      0/      0

  Data OK: 118.93 GB (249424697 sectors)
Data LOST: 0.00 Byte (0 sectors)
	       Corrupted: 0.00 Byte (0 sectors)
	Slightly changed: 0.00 Byte (0 sectors)
	     Overwritten: 0.00 Byte (0 sectors)
Average reading speed: 85.35 MB/s
```

こちらは24分程で完了しました。

ちなみに実行結果に読み書きの速度が出ているので実行環境を示しておきます。マシンはM1 Max搭載MacBook Pro (2021)、OSはSonoma 14.2.1で実行しました。カードリーダーはThunderbolt 3ドックのTS3 Plusに搭載されているものを使用しました。また、microSD-SDカードの変換アダプターは家に転がっていたSanDiskのアダプターを使っています（たぶんだいぶ前に買ったmicroSDの付属品）。

## イメージの書き込み

そういえばRaspberry Pi 4からネットワークインストールできなかったっけ？　と思ったんですが、

https://www.raspberrypi.com/documentation/computers/getting-started.html#install-over-the-network

>  Currently, Network Install is not available on Raspberry Pi 5. Support will be added in a future bootloader update.

ということだったので、素直にMacでイメージを焼くことにしました。

（※この部分を書いていた時点では上のような記述でしたが、現在は対応しているので記述が変わっています）

[Raspberry Pi Imager](https://www.raspberrypi.com/software/)でイメージを書き込みます。この辺の手順は概ね過去に作ろうとして放置している[Raspberry Pi k8sクラスタの記事]({{< ref "2022-03-31-rpi-cluster-01" >}})のものと同じです（UIの方は若干変わっていたけど）。今回セットアップするRaspberry Pi 5は開発マシンとしてデスク上に置いておくけどSSH接続して使う予定なので、ヘッドレス運用を想定したセットアップをしました。つまりその辺も前記の記事と同様です。

書き込みが終了したらmicroSDをRaspberry Pi 5に差し込んで起動します。

## 起動確認

初回起動だけはファイルシステムの拡張などの関係で時間がかかります。いつ終わるかわからないので、最初はディスプレイに繋いで出力だけはチェックしておきます。時間は計ってませんが128GBのmicroSDだとそれなりにかかります。

イメージ書き込み時に指定したホスト名でSSHしてログイン可能であること、とりあえず`apt update && apt upgrade`を叩いて更新できることなどを確認しました。

## 記事再始動とブートローダーの確認

さて、3月に届いた直後にここまで書いて力尽きてたんですが、7月にArgon ONE V3を購入したので真面目に使い始めようと思って続きを書き始めています。

ひとまずSDカードから起動した状態で現在のブートローダーのバージョンを確認してみました。

```
$ sudo rpi-eeprom-update
*** UPDATE AVAILABLE ***
BOOTLOADER: update available
   CURRENT: Wed  6 Dec 18:29:25 UTC 2023 (1701887365)
    LATEST: Wed  5 Jun 15:41:49 UTC 2024 (1717602109)
   RELEASE: default (/lib/firmware/raspberrypi/bootloader-2712/default)
            Use raspi-config to change the release.
```

`2023-12-06`が使われています。[公式のリリースノート](https://github.com/raspberrypi/rpi-eeprom/blob/master/firmware-2712/release-notes.md)を確認するとその後結構な頻度で更新されています。先ほどネットワークブートは非対応ということになっていたのですが、これも`2024-01-15`で対応しています。2月にはdefaultも更新されてるので、新しいブートローダーで出荷されていれば最初からネットワークブートができそうです。

そういうわけで更新してチャレンジしたんですがなんかディスプレイ出力もなくなってよくわからん状態になったので諦めました。人生諦めも肝心。

## ケースへの組み込み

さて、Argon ONE V3 M.2ケースですが、これはM.2 NVMe SSDの組み込みに対応したケースです。ケースにM.2端子があり、ケースとRaspberry Pi本体との接続にはフレキシブルケーブルを使います。丁寧なマニュアルもついていますが一通り手順をさらってみます。

まずはHDMI-電源ボードを接続します（撮影がド下手なのと机が汚いのは目を瞑って頂いて……）。

{{< fluid_imgs "pure-u|/images/2024-07-16-rpi5-board-connected.jpg|Pi 5 connected to HDMI-Power board" >}}

説明書にもしっかり差し込めと書いてあるのでしっかり差し込みましょう。ちなみにこの写真の時点ではSoCにヒートシンクがついていますが、当然ながらこれは剥がさないとダメです。

その後ケース側にサーマルパッドを付けます。サイズが全然合わないのが不安要素。

{{< fluid_imgs "pure-u|/images/2024-07-16-rpi5-thermalpad.jpg|Thermal pad placed" >}}

Raspberry Pi本体のコネクタにフレキシブルケーブルを差し込みます。ケーブル先端に見えている端子が本体のコネクタの白い方に向くようにします。黒い部分を引き上げてからケーブルを差し込み、黒い部分を押し込んで固定します。これも固定されてるのかめちゃくちゃ不安になります。確認のために引っ張るとそれで壊しそうだし……。

{{< fluid_imgs "pure-u|/images/2024-07-16-rpi5-pcie-flexcable.jpg|PCIe flexible cable connected" >}}

ここで写真が途切れてるんですが、あとはDACボードの接続、ケース側のPCIe端子へのフレキシブルケーブル接続を行い、ボードをケースに固定します。最後にケースの上下を組み付けて、SSDを組み込みます。SSDを組み込んだところだけ写真がありました。[Argon 40の販売ページ](https://argon40.com/products/argon-one-v3-m-2-nvme-case)を見るとWD SN580は動作確認済みリストにありませんが、今のところ問題無く動作しています。

{{< fluid_imgs "pure-u|/images/2024-07-16-rpi5-ssd.jpg|SSD placed" >}}

この状態からサーマルパッドを貼り付けてフタを戻してねじ止めすれば作業完了です。

ところで、エルミタージュ秋葉原に[M.2スロットやDAC、高冷却ファン、電源スイッチ搭載のフル装備Raspberry Pi 5用アルミケース](https://www.gdm.or.jp/crew/2024/0701/545413)というこのケースの千石電商への入荷を伝える記事があって、こういう記述があるのですが

> また、トップカバー側には背面の3.5mmジャックを有効化するDAC拡張ボードを内蔵。
> （中略）
> ...やや機能を減らしたベーシックモデルの「PI5-CASE-ARGON-ONE」（税込6,180円）も入荷している。
> こちらはM.2スロットをオミットした分スリムな形状になっており、DAC拡張ボードも搭載していない。ただし背面の3.5mmジャックを有効化するには、別途（「PI5-CASE-ARGON-ONE-M.2」に搭載されているものと同じ）「PI5-CASE-ARGON-ONE-DAC」（税込5,180円）を組み込む必要がある。

とあるんですが（2024-07-16現在）、**どちらのモデルもDACボード(BLSTR DAC)は同梱されてません**。[千石電商の販売ページ](https://www.sengoku.co.jp/mod/sgk_cart/detail.php?code=EEHD-6CZ3)にも

> DAC拡張ボードを接続し、3.5mmオーディオジャックを有効にするサポート(DACボードは別売り)

と明確に別売りと書いてあるんですが、千石電商の店頭に~~あった~~サンプル展示されていたのは確かBLSTR DAC搭載済みっぽくて、オーディオケーブルも生えてたので記者の方が勘違いをしてそうです。

（「店頭にあった」だけだと売り物として置いてあったものとも読めるので、実機サンプルとして展示されていたものであると明記しました）

## SSDへのOSインストール

ケースの組み立てを行って起動したら、SSDが認識できているかを確認します。

```
$ lspci
0000:00:00.0 PCI bridge: Broadcom Inc. and subsidiaries BCM2712 PCIe Bridge (rev 21)
0000:01:00.0 Non-Volatile memory controller: Sandisk Corp WD Blue SN580 NVMe SSD (DRAM-less) (rev 01)
0001:00:00.0 PCI bridge: Broadcom Inc. and subsidiaries BCM2712 PCIe Bridge (rev 21)
0001:01:00.0 Ethernet controller: Raspberry Pi Ltd RP1 PCIe 2.0 South Bridge

$ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
mmcblk0     179:0    0 230.6G  0 disk
├─mmcblk0p1 179:1    0   512M  0 part /boot/firmware
└─mmcblk0p2 179:2    0 230.1G  0 part /
nvme0n1     259:0    0 931.5G  0 disk
```

NVMe SSDはPCIeデバイスとして見えるので`lspci`で確認すると、2番目にSSDが見えています。また、`lsblk`で見ると`nvme0n1`として認識されているのが確認できます。今回は完全に新品のものを入れたのでパーティションもありません。

ここまでやったところでヘッドレス状態のRaspberry PiからどうやってOSイメージをSSDに焼き込むのかということに気付いてしまいました。SSDをケースから取り外せばいいんですが些か面倒です。少し調べてみると、どうやらCLIモードも存在しているようなので試してみることにします（[ Use without GUI from cli-script #460](https://github.com/raspberrypi/rpi-imager/issues/460)）。

まずRaspberry PiにRaspberry Pi Imagerをインストールします。

```
$ sudo apt install rpi-imager
```

`--cli`を渡すとCLIモードになります。ひとまずオプションを確認してみます。

```
$ rpi-imager --cli
Usage: --cli [--disable-verify] [--sha256 <expected hash> [--cache-file <cache file>]] [--first-run-script <script>] [--debug] [--quiet] <image file to write> <destination drive device>
```

書き込みたいイメージファイルと書き込み先のデバイス名がわかっていればよいみたいです。

イメージファイルは[Raspberry Pi OS公式](https://www.raspberrypi.com/software/)から、"See all download options"のリンクを辿れば各種イメージへのリンクがあります。今回は64bit版のLiteを選択しました。

```
$ curl -LO https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-07-04/2024-07-04-raspios-bookworm-arm64-lite.img.xz
$ echo '43d150e7901583919e4eb1f0fa83fe0363af2d1e9777a5bb707d696d535e2599 2024-07-04-raspios-bookworm-arm64-lite.img.xz' | sha256sum -c -
2024-07-04-raspios-bookworm-arm64-lite.img.xz: OK
```

ダウンロードできたら焼いてみます。デバイスを触りに行くので`sudo`が必要です。GUIから操作する場合と同じく書き込みと検証が行われます。

```
$ sudo rpi-imager --cli ./2024-07-04-raspios-bookworm-arm64-lite.img.xz /dev/nvme0n1
...
Write successful.
```

完了後に`lsblk`を叩くと`nvme0n1`にパーティションが生えています。

```
$ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
mmcblk0     179:0    0 230.6G  0 disk
├─mmcblk0p1 179:1    0   512M  0 part /boot/firmware
└─mmcblk0p2 179:2    0 230.1G  0 part /
nvme0n1     259:0    0 931.5G  0 disk
├─nvme0n1p1 259:3    0   512M  0 part
└─nvme0n1p2 259:4    0   2.1G  0 part
```

GUIでは書き込み時点で色々と設定ができましたが、CLIからの操作でそういったことはできなさそうです。ではGUIの時はどうやってカスタマイズしているのか、Raspberry Pi Imagerの実装を見てみました。

[`OptionsPopup.qml`の`applySettings()`](https://github.com/raspberrypi/rpi-imager/blob/qml/src/OptionsPopup.qml#L605)で設定値を反映した文字列を組み立てて、[`downloadthread.cpp`の`_customizeImage`](https://github.com/raspberrypi/rpi-imager/blob/686ad14308639b0589a2971903066f56271033e7/src/downloadthread.cpp#L898)が書き込まれるイメージにファイルを配置してそうです。いくつか分岐がありますが、今起動しているRaspberry Piでは`/boot/firmware/user-data`はありませんし、`/boot/firmware/issue.txt`を見ると`pi-gen`の文字が見えているので、恐らく`_initFormat`は`systemd`で処理が進むはずです。これを前提とすると、`firstrun.sh`というスクリプトをブートパーティションに配置し、さらに`cmdline.txt`を書き換えてこのスクリプトを実行させているようです。

`firstrun.sh`は末尾で自分を削除して`cmdline.txt`も掃除しているので、この辺のソースコードを読んで同じことをするスクリプトを配置してもいいんですが、変数埋めてコピペするよりも適当なSDカードをMacに挿してRaspberry Pi Imagerでイメージを書き込んで取り出す方が早そうなのでそうしました。書き込みが完了すると一旦SDカードは取り出されますが、もう一度Macに挿すとブートパーティションが見えます。ここから`cmdline.txt`と`firstrun.sh`を取り出してSSDに配置します。

```
$ sudo mkdir /mnt/boot
$ sudo mount /dev/nvme0n1p1 /mnt/boot
$ sudo cp firstrun.sh /mnt/boot/
$ sudo mv cmdline.txt /mnt/boot/cmdline.txt
mv: failed to preserve ownership for '/mnt/boot/cmdline.txt': Operation not permitted
$ cat /mnt/boot/cmdline.txt
console=serial0,115200 console=tty1 root=PARTUUID=a3f161f3-02 rootfstype=ext4 fsck.repair=yes rootwait quiet init=/usr/lib/raspberrypi-sys-mods/firstboot cfg80211.ieee80211_regdom=JP systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target
$ cat /mnt/boot/firstrun.sh
#!/bin/bash

set +e

CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom set_hostname foo
else
   echo foo >/etc/hostname
   sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\tfoo/g" /etc/hosts
fi
FIRSTUSER=`getent passwd 1000 | cut -d: -f1`
FIRSTUSERHOME=`getent passwd 1000 | cut -d: -f6`
...
$ sudo umount /mnt/boot
```

`cmdline.txt`の`mv`は怒られましたが、内容は書き換わっていたしユーザーも`root:root`だったので放置しました。`firstrun.sh`も一応内容を確認しておきました。

シャットダウンする前にブートデバイスの優先順位を確認しておきます。ブートの際にどの順番で試みるかは[`BOOT_ORDER`](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#BOOT_ORDER)という設定で決まります。

```
$ sudo rpi-eeprom-config
[all]
BOOT_UART=1
POWER_OFF_ON_HALT=0
BOOT_ORDER=0xf461
```

`0xf461`と設定されていますが、これはSDカード→NVMe→USBの順で起動を試みて、ダメなら最初に戻って繰り返すという設定です。NVMe SSDから起動させるにはこの設定を`0xf416`に変えてNVMeを優先させるか、単にSDカードを抜いておけばよいです。今回はSDカードを抜いておくことにしました。

ただ今回使っているArgon ONE V3 M.2 NVMEケースなんですが、「M.2あるんだからmicroSDなんて使わんだろ」ということなのか、ケースに入れた状態ではRaspberry Pi本体のmicroSDカードスロットにアクセスできません。SSDでのブートでトラブった際にmicroSDから起動したいとなるとケースを開ける必要がある点には注意が必要です。なので、きちんとSSDからブートできることを確認してからケースのネジ止めをしましょう。なおM.2スロット非搭載のArgon ONE V3はケースに開口部があってmicroSDカードスロットにアクセスできます。

そんなわけでケースを開けっぱなしにしたままで電源を投入します。M.2スロットがケース底面側にあってフレキシブルケーブルむき出しのままでの作業なので十分注意しましょう（ケースをネジ止めしとく方がまだマシかもしれない……）。ホストキーが変わっているので事前に`ssh-keygen -R $HOST`で`known_hosts`からエントリを削除しておきましょう。sshできたら`lsblk`でブロックデバイスの一覧を見てみます。

```
$ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:0    0 931.5G  0 disk
├─nvme0n1p1 259:1    0   512M  0 part /boot/firmware
└─nvme0n1p2 259:2    0   931G  0 part /
```

SSDしか見えてないのでたぶん大丈夫そうです。シャットダウンしてケースを閉じます。

## ベンチマーク

### システム

GeekBench 6がプレビュー版ですがLinux/aarch64版を出しているので実行してみます。

```
$ wget https://cdn.geekbench.com/Geekbench-6.3.0-LinuxARMPreview.tar.gz
...

$ tar xvf Geekbench-6.3.0-LinuxARMPreview.tar.gz
Geekbench-6.3.0-LinuxARMPreview/
Geekbench-6.3.0-LinuxARMPreview/geekbench.plar
Geekbench-6.3.0-LinuxARMPreview/geekbench6
Geekbench-6.3.0-LinuxARMPreview/geekbench_aarch64
Geekbench-6.3.0-LinuxARMPreview/geekbench-workload.plar

$ cd Geekbench-6.3.0-LinuxARMPreview/

$ ls
geekbench6  geekbench_aarch64  geekbench.plar  geekbench-workload.plar

$ ./geekbench6
Geekbench 6.3.0 Preview : https://www.geekbench.com/

Geekbench 6 for Linux/AArch64 is a preview build. Preview builds require an
active Internet connection and automatically upload benchmark results to the
Geekbench Browser.

System Information
  Operating System              Debian GNU/Linux 12 (bookworm)
  Kernel                        Linux 6.6.31+rpt-rpi-2712 aarch64
  Model                         Raspberry Pi 5 Model B Rev 1.0
  Motherboard                   N/A

CPU Information
  Name                          ARM ARMv8
  Topology                      1 Processor, 1 Core, 4 Threads
  Identifier                    ARM implementer 65 architecture 8 variant 4 part 3339 revision 1
  Base Frequency                2.40 GHz

Memory Information
  Size                          7.86 GB

...
```

スコアはシングルコアが798、マルチコアが1599でした。公式ブログの[Benchmarking Raspberry Pi 5](https://www.raspberrypi.com/news/benchmarking-raspberry-pi-5/)にある結果と比べると、まぁほぼ誤差程度のスコアになっているかなと思います。ちなみに[このブログ記事のコメント](https://www.raspberrypi.com/news/benchmarking-raspberry-pi-5/#comment-1595124)によれば（恐らく公式の）Active Coolerを使用しているとのことです。Argon ONE V3は冷却について考えてあるものの「重視してる」レベルではないように思われるので、もっとゴリゴリに冷やしてあげれば伸びる……かも。

なお詳細な結果はこちらのリンクから見られます: https://browser.geekbench.com/v6/cpu/6862003

### SSD

ストレージのベンチマークとしてPi Benchmarksを実行してみました。
まずデフォルト状態である、PCIe 2.0 x1での結果を見てみます。

```
$ sudo curl https://raw.githubusercontent.com/TheRemote/PiBenchmarks/master/Storage.sh | sudo bash
...
     Category                  Test                      Result
HDParm                    Disk Read                 391.16 MB/sec
HDParm                    Cached Disk Read          434.70 MB/sec
DD                        Disk Write                297 MB/s
FIO                       4k random read            68039 IOPS (272159 KB/s)
FIO                       4k random write           87521 IOPS (350085 KB/s)
IOZone                    4k read                   179024 KB/s
IOZone                    4k write                  167546 KB/s
IOZone                    4k random read            75154 KB/s
IOZone                    4k random write           180317 KB/s

                          Score: 39018
```

`raspi-config`からPCIe 3.0を有効にして再起動して再実行します。

```
     Category                  Test                      Result
HDParm                    Disk Read                 759.79 MB/sec
HDParm                    Cached Disk Read          836.36 MB/sec
DD                        Disk Write                433 MB/s
FIO                       4k random read            215578 IOPS (862315 KB/s)
FIO                       4k random write           93515 IOPS (374063 KB/s)
IOZone                    4k read                   227825 KB/s
IOZone                    4k write                  218295 KB/s
IOZone                    4k random read            86237 KB/s
IOZone                    4k random write           251895 KB/s

                          Score: 55508
```

スコアでは1.4倍程度、hdparmでは倍近い結果になってますね。PCIe 2.0でも恐らくSDカードよりは遙かに高速でしょう。

かつては`config.txt`を直接弄らないといけなかったPCIe 3.0接続ですが、`raspi-config`から設定ができるようになり、より手軽さが増したように思えます。一方でM.2スロットと本体の接続がフレキシブルケーブルというのがかなりの不安要素ではあります。安定を取るならPCIe 2.0運用が良いかと思いますが、まぁM.2 SSD HAT使うような人は安定取らないですよね！！！

## まとめ

* NVMe SSDにするとめっちゃ速くて快適。
* USB経由するよりも無駄にケーブル生やさなくて良いのでスッキリ。
* フレキシブルケーブルこわい。
