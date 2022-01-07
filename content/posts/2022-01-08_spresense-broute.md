---
title: "SpresenseとBP35A1でスマートメーターと通信する"
date: 2022-01-08T02:40:00+09:00
author: Mei Akizuru
slug: spresense-broute
tags:
    - tech
    - spresense
    - b-route
---


## 背景

結構前にスマートメーターに切り替わり、このタイミングで電力消費量なんかを取れないかと調べてみてBルートサービスなるものがあることを知った。

スマートメーターとWi-SUNなる規格で通信して情報を取得できるが、このモジュールがなかなか高価で尻込みしていた。しかし、最近どうもブレーカーが落ちる頻度が上がってきた感じがあったので、電力使用量をモニタリングしてみようと思ったものである。

そういうわけでBP35A1と一式を集め、「さて余っていたRaspberry Piがあったはず……」と探してみたが引っ越しのタイミングで行方不明となってしまっていた。そこで最近久しぶりに触っていたSpresenseを代わりに使ってみることにした。

## 用意したもの

| 品名               | 説明                                                                                                           |
| ------------------ | -------------------------------------------------------------------------------------------------------------- |
| BP35A1             | スマートメーターと通信するためのWi-SUN規格対応モジュール。Amazonで入手。                                       |
| BP35A7A            | BP35A1のブレークアウトボード。マルツオンラインで入手。                                                         |
| BP35A7-accessories | BP35A7Aのピンヘッダ、BP35A7AにBP35A1を固定するためのスペーサー、ネジ、ナットのセット。秋葉原の千石電商で入手。 |
| Spresense          | ソニーのシングルボードコンピュータ。発売当初に秋葉原のツクモロボット王国（閉店済み）で買ったような気がする。   |
| その他いろいろ     | ブレッドボード、ジャンパーワイヤー、はんだごて一式、etc.                                                       |

一式注文してこの記事を書き始めたのが実は2021年8月下旬なのだが、そのときBP35A1とBP35A7Aをマルツオンラインで注文したところ、「BP35A1については在庫切れで、今から発注して納期は来年（2022年）3月」という連絡を受けてBP35A7Aのみ手配してもらった。そこから慌てて他のBP35A1の在庫を探してAmazon.co.jpで在庫有りだったので即注文してgot kotonakiしたが、今（2022年1月）探してみるとどこも本当に在庫がない。そういうわけでこの記事の内容はモノがなくて試すのが難しい状況にある。


## 開発環境

* MacBook Pro (2016)
* macOS BigSur (11.5.2)
* Visual Studio Code (1.59.1)
  * Spresense VSCode IDE (1.2.1)


## やったこと

### BP35A1とBP35A7Aの準備

BP35A1とBP35A7Aを接続する。向きがあるのでデータシートを見て確認しておく（BP35A1のアンテナ部がBP35A7Aの外側に出るようにする）。2つのボードの間にスペーサーを挟み、ネジとナットで固定する。

BP35A7Aにピンヘッダをはんだ付けする。


### 接続・動作確認

ブレッドボードにBP35A7Aを挿し、配線する。

| Spresense | BP35A7A     |
|-----------|-------------|
| 3.3V      | VCC (CN1-4) |
| GND       | GND (CN1-1) |
| TX        | RXD (CN2-4) |
| RX        | TXD (CN2-5) |

その他データシートでGND接続推奨になってる箇所も一通りGNDに繋いでおいたが、たぶんしなくても動く。フロー制御は行わないのでその辺の配線も省略。

Spresenseの開発環境はVSCode IDEを使用する。事前にSpresense SDK IDE編のセットアップを済ませておく。

USBでSpresenseと接続すると `/dev/cu.SLAB_USBtoUART` が見えるので、これをシリアルポートとして選択する。

Spresense SDKのコンフィグで、`SYSTEM_CUTERM`を有効にする（メニュー名は"Application Configuration > System Libraries and NSH Add-Ons > CU minimal serial terminal"）。これでNuttShell上で`cu`コマンドが使えるようになる。

シリアルターミナルを開いたら、`ls /dev` を叩いてデバイスを確認する。

```
nsh> ls /dev
/dev:
 console
 i2c0
 mtdblock0
 null
 rtc0
 smart0d1
 sysctl
 timer0
 timer1
 ttyS0
 ttyS2
 usrsock
 watchdog0
```

SpresenseのTX/RXピンはUART#2に対応していて、これは`/dev/ttyS2`として見えているので、`cu`コマンドでこのデバイスを開く。

`cu`コマンドの使い方は`-?`で確認できる。実際に実行すると次のように表示される。

```
nsh> cu -?
Usage: cu [options]
 -l: Use named device (default /dev/ttyS0)
 -e: Set even parity
 -o: Set odd parity
 -s: Use given speed (default 115200)
 -r: Disable RTS/CTS flow control (default: on)
 -?: This help
```

BP35A1のデータシートによればボーレートは115200なので、これはデフォルトで良い。記載の通り、`cu`コマンドではフロー制御がデフォルトで有効になっているが、今回フロー制御のピンを繋いでいないので`-r`オプションで無効にする。

接続確認のため、BP35A1のファームウェアバージョンを確認するコマンド `SKVER` を送る。`EVER`に続いてバージョン番号、続いて`OK`が返ってきたら接続に問題はない。

```
nsh> cu -l /dev/ttyS2 -r
SKVER
EVER 1.2.10
OK
```

`cu`から抜ける際は`~.`を入力する。

ここまで問題なければ、続けて試しにスマートメーターとの接続まで行ってみる。やることは次の通り。

1. BルートのIDとパスワードを設定する
2. 接続先のスマートメーターをスキャンする
3. スキャンした結果から通信チャンネル、PAN IDを設定する
4. スマートメーターのアドレスをIPv6アドレスに変換する
5. スマートメーターとの間で認証を成立させて通信を開始する

実際に`cu`内でやってみるとこんな結果になる（アドレス部分等は潰している）。`(n)`は`n`番目の手順と対応する操作を表す。

```
# (1)
SKSETRBID <ID>
OK
SKSETPWD C <PW>
OK
# (2)
SKSCAN 2 FFFFFFFF 6
OK
EVENT 20 0000:0000:0000:0000:0000:0000:0000:0000
EPANDESC
  Channel:37
  Channel Page:09
  Pan ID:0123
  Addr:0123456789ABCDEF
  LQI:51
  PairID:01234567
EVENT 22 0000:0000:0000:0000:0000:0000:0000:0000
# (3)
SKSREG S2 37
OK
SKSREG S3 0123
OK
# (4)
SKLL64 0123456789ABCDEF
0000:0000:0000:0000:0000:0000:0000:0000
# (5)
SKJOIN 0000:0000:0000:0000:0000:0000:0000:0000
OK
EVENT 21 0000:0000:0000:0000:0000:0000:0000:0000 02
EVENT 02 0000:0000:0000:0000:0000:0000:0000:0000
ERXUDP 0000:0000:0000:0000:0000:0000:0000:0000
...
```

認証に成功すると、それ以降`ERXUDP`というイベントが送られてくるようになる。これはUDPパケットの受信イベントで、この内容を適宜読んでいくことになる。

`SKSCAN`コマンドでスキャンを開始すると、`EVENT 20`に続けて`EPANDESC`というイベントが送られてくる。`EPANDESC`に続く内容がスキャンして得られたデバイスの詳細情報で、必要になるのは`Channel`、`Pan ID`、`Addr`の3つである。

通信チャンネルとPAN IDは`SKSREG`コマンドでそれぞれレジスタ`S02`と`S03`に登録する。`Addr`はEUI-64のアドレスで、`SKLL64`コマンドでこれをIPv6アドレスに変換してから`SKJOIN`コマンドの引数として使用する。なお、`SKLL64`を使わなくとも次の法則でIPv6アドレスを生成出来る。

* 前半64ビットは FE80:0000:0000:0000 （生成されるのはリンクローカルアドレス）
* 後半64ビットは **先頭から7ビット目（先頭バイトの下位から2ビット目）を反転して** 元のアドレスをコピーする

アドレスが分かったら `SKJOIN` で認証を行う。


### 通信用のコードを書く

UARTによるシリアル通信だが、その辺はOS(NuttX)側で上手く抽象化されているので前述の `/dev/ttyS2` をオープンして読み書きする。少なくともBP35A1との通信はテキストベースだと思ってよいが、スマートメーターとの通信ではバイナリを読み書きする必要があるので注意が必要である。

BP35A1とのやりとりで注意すべき点はだいたい次の点だと思う。

* 改行コードはCRLF。コマンド入力は改行で終端されるので、これを間違うと永遠に反応が来ない（読み出す分には余計な`\r`が行末にくっつくだけなので実害は少なめ）。
* デフォルトではコマンドのエコーバックが有効になっている。つまりコマンドを送って直後に `OK` を期待するようなコードを書くとエコーバックで誤動作する。1行読み飛ばすか、`SFE`レジスタを`0`に設定してエコーバックを無効にするとよい。

#### そもそも通信できない問題

巷にはRaspberry Piを使ったりArduinoだったりで取得する記事が多いので、あえてのSpresense SDK (C/C++)や！　と変な気を起こしたのが運の尽き。

まず最初で最大の関門となったのが「何故か正常にレスポンスが読み出せない」問題だった。

* SDKではなくSpresense Arduinoを使い、`Serial`で通信してみる → **動作する**
* `\r\n`ではなくコマンド行を送った後に `0x0d, 0x0a` を送るようにしてみた → 変わらない
* 対向をBP35A1ではなくRaspberry PiにしてSpresenseがUARTを通して送ってる内容をダンプしてみる → 特におかしなところはない
* プログラムからコマンドを送った後、nshに戻ってcuしてEnterすると「不明なコマンド」的なエラーを返される → **それは改行コード送れてない説ない？**

などなど、諸々の試行錯誤や動作検証を経て、最終的には **Spresense起動後のエントリポイントをnshではなく自作プログラムにする** ことで解決した（Spresense Arduinoだったら動く、Spresense Arduino使用時はnshが起動しない、という点から思いついた）。

タスク優先度の関係で送信途中にタスクが変わって正しく送れてない、もしくは受信したデータを誰かに横取りされてる、`nsh`が起動した時点で入力に何かしらフック噛まされてる、とか考えているが、原因はさっぱり分かっていない。


#### イベントハンドリング

`SKSREG`や`SKSETRBID`といった何かしら設定をするタイプのコマンドを取り扱っている間は特に問題はないのだが、スキャン系のコマンド、あるいはUDPパケット受信などは「イベント」として通知されてくる。よって、最初の設定が一通り終わったらイベントを処理するループを回すことになる。

注目・処理すべきイベントは次の通り。

| イベント   | 内容                                                                   | やること                       |
| ---------- | ---------------------------------------------------------------------- | ------------------------------ |
| `EPANDESC` | アクティブスキャンで検出されたPANの情報通知。                          | PANの情報を取り出す。          |
| `EVENT 22` | アクティブスキャンの終了通知。                                         | 通信対象のPANを決定する。      |
| `EVENT 24` | 接続失敗通知。                                                         | エラーハンドリング、リトライ。 |
| `EVENT 25` | 接続完了通知。この通知が来たら無線通信を開始してよい。                 | 処理を次に進める。             |
| `EVENT 29` | セッションタイムアウト通知。この通知が来たら無線通信をしてはならない。 | 再接続する。                   |
| `ERXUDP`   | UDPパケット到着通知。パケットのペイロードが入っている。                | パケットを処理する。           |

無限ループを回して1行を読み続け、読んだ行をスペース区切りにして読み出す形になる(`strtok(buf, " ")`)。ただし`ERXUDP`については最後にペイロードがバイナリそのまんまで入ってくるので、素直に`fgets`っぽい挙動（改行文字もしくは`NULL`で終端とみなす）で読んでいくとバグるかもしれない。面倒なのでそこをケアする実装にはしていないが、今のところそれでバグってはいない。`WOPT 01`を実行すると、バイナリ部がhex stringになるので、初期化時にこれをやっておく手もある（hex stringを解釈するのと、改行や
NULLを考慮するのとどちらが楽だろう……）。

```c
void *event_main(void *arg) {
  Context *ctx = (Context *)arg;
  char buf[256];
  while (true) {
    int ret;
    if ((ret = read_serial(ctx->fd, buf, 256)) < 0) {
      return ret;
    }
    char *cmd = strtok(buf, " ");
    if (cmd == NULL) {
      continue;
    }
    if (strcmp(cmd, "OK") == 0) {
      ctx->response = RS_OK;
    } else if (strcmp(cmd, "FAIL") == 0) {
      char *code_s = strtok(NULL, " ");
      int code;
      sprintf(code_s, "ER%2d", &code);
      ctx->response = (ResponseStatus)code;
    } else if (strcmp(cmd, "ERXUDP") == 0) {
      char *sender_s = strtok(NULL, " ");
      uint8_t sender[16];
      parse_ipv6_addr(sender_s, sender);

      /* ... */

      uint8_t *data = (uint8_t *)malloc(data_len);
      memcpy(data, data_len_s + 5, data_len);

      handler_erxudp(ctx, sender, dest, rport, lport, sender_lla, secured,
                     data_len, data);
      free(data);
    } else if (strcmp(cmd, "EEDSCAN") == 0) {
      /* ... */
    } else if (strcmp(cmd, "EVENT") == 0) {
      char *num_s = strtok(NULL, " ");
      /* ... */
      handler_event(ctx, num, sender, param);
    } else if (strcmp(cmd, "EPANDESC") == 0) {
      memset(buf, 0, 256);
      if ((ret = read_serial(ctx->fd, buf, 256)) < 0) {
        return ret;
      }
      uint8_t channel;
      sscanf(buf, "  Channel:%2X", &channel);

      /* ... */

      handler_epandesc(ctx, (Channel)channel, channel_page, (uint16_t)pan_id,
                       addr, (uint8_t)lqi);
    } else {
      // no handler
    }
  }
}
```

だいぶ端折ったが、Cで文字列処理を書くもんじゃないなという思いがある。

今回はこのイベントループを別スレッドで回すように実装した。`Context`という構造体を定義し、メインスレッドで初期化、イベントスレッドにポインタを渡してやりとりする形となっている。基本的にイベントスレッドとメインスレッドで同じフィールドを同時に触ることはないはずなので読み書きについてノーロック戦法を採っているが、いつか分かりにくいバグを生む可能性は否定できない。

NuttXではpthreadが使えるのでスレッドを生やすところは`pthread_create`を呼べばよい。ちなみにNuttXにはタスクという概念もあるが、その辺は公式ドキュメントを参照してほしい: [Tasks vs. Threads FAQ](https://cwiki.apache.org/confluence/display/NUTTX/Tasks+vs.+Threads+FAQ)。

```c
#include <pthread.h>

int broute_main(int argc, char *argv[]) {
  // ...
  Context *ctx = context_new();
  pthread_t ptid;
  if (pthread_create(&ptid, NULL, event_main, ctx)) {
    perror("main: create event thread");
    bp35a1_close(client);
    return -1;
  }
  // ...
}
```


#### ECHONET Liteフレーム

スマートメーターとの通信は[ECHONET Lite](https://echonet.jp/)という規格で行う。これがUDPの上に乗っているので、つまり`ERXUDP`イベントのペイロードはECHONET Lite仕様に則った形になっているというわけである。

補足: ECHONET Liteの仕様としてはOSIモデルでいうL4以下がなんであるかは規定していないが、HEMSコントローラとスマートメーター間のアプリケーション通信インターフェース仕様はUDP/IPv6を想定して書かれている。

この規格の仕様は https://echonet.jp/spec_g/#standard-01 で公開されている。見なければならないのは次の3つ。

* ECHONET Lite規格書 第2部 ECHONET Lite 通信ミドルウェア仕様
* アプリケーション通信インターフェース仕様書 低圧スマート電力量メータ・HEMSコントローラ間
* APPENDIX ECHONET機器オブジェクト詳細規定Release P

データ仕様を確認していく。まず、ECHONET Liteフレームは次のように構成されている。

| オフセット | 長さ | 名前    | 内容                                                                                                    |
| ---------- | ---- | ------- | ------------------------------------------------------------------------------------------------------- |
| 0          | 1    | `EHD1`  | ヘッダ1（常に `0b00010000` = `0x10` ）。                                                                |
| 1          | 1    | `EHD2`  | ヘッダ2。EDATAのフォーマットを指定する。                                                                |
| 2          | 2    | `TID`   | トランザクションID。リクエスト時に任意の値を指定する。レスポンスには対応するリクエストと同じTIDが入る。 |
| 4          | n    | `EDATA` |データの本体。                                                                                           |

NOTE: データはビッグエンディアンでやりとりされる。

`EHD2`が`0x81`なら`EDATA`は「規定電文形式」であり、`0x82`なら「任意電文形式」である。任意電文形式の場合`EDATA`の解釈は完全にアプリケーションに委ねられる。ただし今回任意電文形式の出番はない。

規定電文形式の場合、`EDATA`は次のように構成される。

| オフセット | 長さ | 名前    | 内容                                                  |
| ---------- | ---- | ------- | ----------------------------------------------------- |
| 0          | 3    | `SEOJ`  | 送信元のECHONET Liteオブジェクト。                    |
| 3          | 3    | `DEOJ`  | 送信先のECHONET Liteオブジェクト。                    |
| 6          | 1    | `ESV`   | ECHONET Liteサービス。                                |
| 7          | 1    | `OPC`   | プロパティ数。この数だけ以降3つの構造が繰り返される。 |
| 8          | 1    | `EPC1`  | 1つ目のECHONET Liteプロパティ。                       |
| 9          | 1    | `PDC1`  | `EDT`の長さ（バイト数）。`0`のこともある。            |
| 10         | n    | `EDT1`  | プロパティの値。                                      |

補足: オブジェクトとかサービスとかプロパティとかの用語はあんまり分からなくても実装できるので、詳細に興味のある人は仕様書を読んでいただきたい。

プロパティの数はたぶん1以上だが（プロパティを1つも含まないリクエスト・レスポンスに意味がないはず）、`PDC`が`0`、つまり`EDT`が空になることはありうる。こんな感じでフォーマットが決まっているので前の方から順番に読んでいけばフレームを解釈できる。

とりあえずこの仕様をそのまま構造体に落とし込んでみる。

```c
typedef struct {
  uint8_t class_group_code;
  uint8_t class_code;
  uint8_t instance_code;
} EOJ;

typedef struct {
  /// ECHONET Lite property specifier.
  uint8_t epc;
  /// A length of EDT in bytes.
  uint8_t pdc;
  /// Property value.
  uint8_t *edt;
} ELProperty;

typedef struct {
  /// EOJ of sender.
  EOJ sender;
  /// EOJ of destination.
  EOJ dest;
  /// ECHONET Lite service specifier.
  uint8_t esv;
  /// A number of properties.
  uint8_t opc;
  /// ECHONET Lite properties.
  ELProperty **properties;
} ELDefiendData;

typedef union {
  ELDefiendData *defined;
  struct { size_t size; uint8_t *data; } arbitrary_data;
} EDATA;

typedef struct {
  uint8_t ehd1;
  uint8_t ehd2;
  /// Transaction ID.
  uint16_t tid;
  EDATA edata;
} ELFrame;
```

デシリアライズは前から読んでいくだけ。


#### スマートメーターからの情報取得

あるタイミングでの瞬間電力消費量はこちらからリクエストを送って取得する。リクエスト送信は60秒に1回メインスレッドから行う。

リクエストする際のECHONET Liteフレームの各値は次の通り。

| 名前   | 値                   | 意味                                         |
| ------ | -------------------- | -------------------------------------------- |
| `TID`  | 任意の16bit整数      |                                              |
| `SEOJ` | `{0x05, 0xFF, 0x01}` | HEMSコントローラを表すオブジェクト。         |
| `DEOJ` | `{0x02, 0x88, 0x01}` | 低圧スマート電力量メータを表すオブジェクト。 |
| `ESV`  | `0x62`               | プロパティ値読み出し要求。                   |
| `OPC`  | `1`                  |                                              |
| `EPC1` | `0xE7`               | 瞬時電力計測値。                             |
| `PDC1` | `0`                  |                                              |
| `EDT1` | NULL                 |                                              |

これにヘッダとトランザクションIDを付与した上でバイト列に落とし込み、`SKSENDTO`コマンドでスマートメーターへ送信する。送信先ポートはECHONET Liteの仕様で決まっていて、`3610`で固定である。なお、`SKSENDTO`コマンドは引数にデータ長を取るが、そのデータ長分だけデータが書き込まれないとコマンド受け付け状態から抜けないようになっている（そうでないとバイナリデータの中にたまたま`\r\n`が出現してしまったときに不完全なデータになる）。

`ELFrame`を確保する関数を用意する。

```c
ELFrame *make_frame(EDATAForm form, uint16_t tid, EDATA data) {
  ELFrame *frame = (ELFrame *)malloc(sizeof(ELFrame));
  frame->ehd1 = EHD1;
  frame->ehd2 = form;
  frame->tid = tid;
  frame->edata = data;
  return frame;
}
```

リクエストフレームのうち、トランザクションID以外は毎回同じデータを送ればよいので、予め適当なオブジェクトを持っておくと簡単。

```c
// main
  const struct timespec fetch_interval = { 60, 0 };

  EOJ sender = {0x05, 0xFF, 0x01};
  EOJ dest = {0x02, 0x88, 0x01};

  ELDefiendData edata;
  edata.sender = sender;
  edata.dest = dest;
  edata.esv = 0x62;
  edata.opc = 1;
  edata.properties = (ELProperty **)malloc(sizeof(ELProperty *));
  edata.properties[0] = (ELProperty *)malloc(sizeof(ELProperty));
  edata.properties[0]->epc = 0xE7;
  edata.properties[0]->pdc = 0x00;
  edata.properties[0]->edt = NULL;
  EDATA data;
  data.defined = &edata;

  srand(time(NULL));
  while (true) {
    uint16_t tid = (uint16_t)rand();
    printf("main: making frame with tid=%d\n", tid);
    ELFrame *frame = make_frame(DEFINED_FORM, tid, data);
    uint8_t *packed;
    size_t plen = pack_frame(frame, &packed);
    printf("main: sending request\n");
    printf("main: payload (%d bytes) =", plen);
    for (size_t i = 0; i < plen; ++i) {
      printf(" %02X", packed[i]);
    }
    printf("\n");
    if ((ret = bp35a1_sendto(client, 1, addr, EL_PORT, true, plen, packed)) <
        0) {
      printf("main: failed to send UDP packet (%d)\n", ret);
      bp35a1_close(client);
      break;
    }
    context_begin_transaction(ctx, tid, handle_measured_inst_energy);
    nanosleep(&fetch_interval, NULL);
  }
```

リクエストが成功したら次のようなレスポンスが返ってくる。若干時間がかかるので、タイムアウトを仕込む場合は長めにした方が良いかもしれない。

| 名前   | 値                   | 意味                                         |
| ------ | -------------------- | -------------------------------------------- |
| `TID`  | 任意の16bit整数      | リクエスト時に入れた値が入っている。         |
| `SEOJ` | `{0x02, 0x88, 0x01}` | 低圧スマート電力量メータを表すオブジェクト。 |
| `DEOJ` | `{0x05, 0xFF, 0x01}` | HEMSコントローラを表すオブジェクト。         |
| `ESV`  | `0x72`               | プロパティ値読み出し応答。                   |
| `OPC`  | `1`                  |                                              |
| `EPC1` | `0xE7`               | 瞬時電力計測値。                             |
| `PDC1` | `4`                  |                                              |
| `EDT1` | signed 32bit integer | W単位の計測値。                              |

トランザクションIDでリクエストとレスポンスを紐付けられるので、`Context`の中にトランザクションIDと関数の組をリストとして保持し、リクエスト時にそのリストにIDと関数を追加しておき、レスポンス受信時にそのリストからトランザクションIDを探し、見つかったらそれと組になっている関数を呼び出す、という形で処理している（上のコードで`context_begin_transaction`を呼んでるところが登録処理）。

簡単にコードを示しておくと、まずトランザクションはこんな感じの構造体になっている。

```c
typedef void (*TransactionHandlerFunc)(ELFrame *);

typedef struct {
  uint16_t tid;
  TransactionHandlerFunc f;
} TransactionHandler;
```

レスポンスを受信したら`context_done_transaction`を呼び出す。リクエストする時にどんなリクエストかは分かっているので`TransactionHandlerFunc`として対応するレスポンスハンドラを登録しておく。

```c
static void context_done_transaction(Context *ctx, ELFrame *frame) {
  if (thlist_is_empty(ctx->handlers)) {
    return;
  }

  TransactionHandler *th = thlist_get(ctx->handlers, frame->tid);
  if (th != NULL) {
    printf("context(done_transaction): found transaction %d\n", frame->tid);
    th->f(frame);
    thlist_remove(ctx->handlers, frame->tid);
    free(th);
  } else {
    printf("context(done_transaction): transaction %d not found\n", frame->tid);
  }
}
```

今回の場合は瞬間電力計測値のレスポンスを処理するハンドラを登録しておく。こんな感じ。

```c
static void handle_measured_inst_energy(ELFrame *frame) {
  if (frame->ehd2 != DEFINED_FORM) {
    printf("handle_measured_inst_energy: EDATA is not fixed form\n");
    return;
  }
  ELDefiendData *edata = frame->edata.defined;
  if (edata->esv != ESV_GET_RES) {
    printf("handle_measured_inst_energy: ESV is %02X, not Get_Res\n",
           edata->esv);
    return;
  }
  if (edata->opc == 0) {
    printf("handle_measured_inst_energy: there is no properties\n");
    return;
  }
  for (int i = 0; i < edata->opc; ++i) {
    ELProperty *prop = edata->properties[i];
    if (prop->epc == ELHPC_MEASURED_INST_EN) {
      int32_t w = prop->edt[0] << 24 | prop->edt[1] << 16 | prop->edt[2] << 8 |
                  prop->edt[3] << 0;
      printf("handle_measured_inst_energy: %d W (%08X)\n", w, w);
    }
  }
}
```

大雑把に実装の要点を紹介した。他の諸々も実装して動かすと以下のような出力が得られる。

```
main: making frame with tid=31594
main: sending request
main: payload (14 bytes) = 10 81 7B 6A 05 FF 01 02 88 01 62 01 E7 00
event: sending UDP packet succeeded
received UDP packet
  Sender = FE80:0000:0000:0000:0001:0203:0405:0607
  Payload (18 bytes) = 10 81 7B 6A 02 88 01 05 FF 01 72 01 E7 04 00 00 02 63
FRAME: ehd2=81, tid=31594
  CONTENT:
    SEOJ    = 02 88 01
    DEOJ    = 05 FF 01
    Service = 72
    # Props = 1
    Property 0:
      EPC: E7
      PDT: 00 00 02 63 
context(done_transaction): found transaction 31594
handle_measured_inst_energy: 611 W (00000263)
```

#### 積算電力消費量の通知

また、これとは別に、接続が確立した状態では毎時0分と30分にスマートメーター側から積算の電力消費量が「通知」として送られてくる（つまりリクエストしなくても来る）。この情報は次のようなECHONET Liteフレームに乗っている。

| 名前   | 値                   | 意味                                         |
| ------ | -------------------- | -------------------------------------------- |
| `TID`  | 任意の16bit整数      | 規格で定められていない。                     |
| `SEOJ` | `{0x02, 0x88, 0x01}` | 低圧スマート電力量メータを表すオブジェクト。 |
| `DEOJ` | `{0x05, 0xFF, 0x01}` | HEMSコントローラを表すオブジェクト。         |
| `ESV`  | `0x73`               | プロパティ値通知。                           |
| `OPC`  | `1`                  |                                              |
| `EPC1` | `0xEA`               | 定時積算電力量計測値（正方向） 。            |
| `PDC1` | `11`                 |                                              |
| `EDT1` | （後述）             |                                              |

`PDC`が示す通りこの通知の値は11byteあり、計測日時と計測値が入っている。

| オフセット | 長さ | 値     |
| ---------- | ---- | ------ |
| 0          | 2    | 年     |
| 2          | 1    | 月     |
| 3          | 1    | 日     |
| 4          | 1    | 時     |
| 5          | 1    | 分     |
| 6          | 1    | 秒     |
| 7          | 4    | 計測値 |


これも読むだけ。

```c
static void handle_notification(ELFrame *frame) {
  ELDefiendData *edata = frame->edata.defined;
  if (edata->esv != ESV_INF) {
    printf("handle_notification: ESV is %02X, not INF\n", edata->esv);
    return;
  }
  for (int i = 0; i < edata->opc; ++i) {
    ELProperty *prop = edata->properties[i];
    if (prop->epc == ELHPC_FIXED_CUMULATIVE_AMT) {
      uint16_t year = prop->edt[0] << 8 | prop->edt[1];
      uint8_t month = prop->edt[2];
      uint8_t day = prop->edt[3];
      uint8_t hour = prop->edt[4];
      uint8_t min = prop->edt[5];
      uint8_t sec = prop->edt[6];
      uint32_t kwh = prop->edt[7] << 24 | prop->edt[8] << 16 |
                     prop->edt[9] << 8 | prop->edt[10];
      printf("handle_notification: %04d-%02d-%02d %02d:%02d:%02d: %d kWh "
             "(%04X) normal\n",
             year, month, day, hour, min, sec, kwh, kwh);
    } else if (prop->epc == ELHPC_FIXED_CUMULATIVE_AMT_REV) {
      // ...
    }
  }
}
```

ただ、本来はこれで得られた値を実使用量に変換するために`EPC = 0xE1` でリクエストして得られる係数を掛ける必要がある。`0xE1`でリクエストして`0x00`が返ってきたら係数は`1`なので通知された値がそのまま実使用量(kWh)を表すが、例えば`0x01`が来た場合は係数`0.1`を掛けた値が実際の値になる。詳しくはオブジェクト詳細規定を参照してほしい。

ちなみにこれは『正方向』の計測値で、対応していれば`EPC = 0xEB`となっている『逆方向』の計測値も送られてくるが、太陽光発電等で売電をしていないなら無視してよいと思う（たぶん。上のコードでは無視している）。


#### タイムアウトについて

アプリケーション通信インターフェース仕様書で、コントローラは要求を送ってから次の時間は応答を待つべきとされている。

| 条件                                                            | 値      |
| --------------------------------------------------------------- | ------- |
| `OPC >= 2`、もしくは`EPC`が次のいずれか: `0xE2`, `0xE4`, `0xEC` | 60 sec. |
| 上記に該当しない                                                | 20 sec. |

今回のコードでは`EPC = 0xE7`の要求を60秒に1回なので結果的にこの応答待ち時間を満たしている。そもそもタイムアウトとか実装してないしね。

仮にタイムアウトからのリクエスト再送をする場合には、トランザクションIDを使い回してはいけないと定められている点には注意。


## まとめ

RaspberryPiがないのでとりあえず手元にあるもので〜ということでSpresenseでやってみたが、それにしたって大人しくArduino SDK使った方が良かったんちゃうか感が満載である。あとSpresenseの強みであるマルチコアとかGNSSとかハイレゾ対応とかは一切活用していないので、本当にあえてSpresenseを使う理由もあんまりないのがちょっと悲しい。

今回はUART通信が上手くいかないという想定外の障害に見舞われたが、それを除くとしんどいのはたぶんイベント駆動っぽい処理な気がする。特にPANのスキャンはマシン・リーダブルな形で渡してくれないのでしんどい。

とはいえNuttXの勉強になったとか（今後役に立つのかは置いておくとして）、久々にC/C++を書いて昔の感覚をちょっと思い出したとか（今後役に立つのかは以下略）、色々と学ぶことはあった。Spresense SDKで開発するだとかBルート受信アプリを書く一助になれば幸いである。
