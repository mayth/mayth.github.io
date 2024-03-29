---
title: SECCON 2014 オンライン予選 【Print it!】
date: 2014-07-20 18:53:55 +0900
author: Mei Akizuru
slug: seccon2014-online-printit
tags:
  - CTF
  - SECCON
  - SECCON2014
  - Write-up
aliases:
    - /blog/2014/07/20/seccon2014-online-printit/
---

2014-07-19 09:00 - 21:00に行われたSECCON 2014 オンライン予選のWrite-upです。次は「Print it!」。

## 問題概要

謎のファイルが降ってきます。以上。

## 解法

降ってきたファイルの正体は"Standard Triangulated Language"というフォーマットのファイル(参考: [Wikipedia](http://ja.wikipedia.org/wiki/Standard_Triangulated_Language))で、このフォーマットのバイナリ形式で記録された3Dモデルです。このファイルを適切なアプリケーションで開くと3Dモデルを見ることが出来て、そのモデルにフラグが書かれています。

ans: `Bar1kaTaLab.`

## 経緯

とりあえずファイルをバイナリエディタに突っ込んでビットマップで見てみると、かなり規則性の高いらしいということはわかったのですが、それ以上のことはさっぱりわからず。nullが14個くらい続いてたりとか、それが繰り返されてたりとか、その辺の規則性が高いわりに、先頭には普通にテキストが入っているし、テキストの間にはまたもnullが入っていてよくわかんないなぁと思ってました。

先頭のテキストには意味がないんじゃないかと思って削ってみても、削った後の先頭数バイトが何かのシグネチャになってるわけではありませんでした。あと、前述のnullが続いている箇所がかなり多いことから圧縮されているわけでもなさそうだということはわかりました。

問題名がPrint it!なので、きっと何かにPrintするんだろうと思って、仮想プリンタドライバにlprコマンドでデータを送りつけても何も起きませんでした。他に"Print"に関係しそうなファイルフォーマットを考えてみましたが、たいていがテキスト形式のもので、問題ファイルとは噛み合いません。あとpbcopyでコピーしてコンソールに無理矢理突っ込んだらえらい目にあいました。

じゃあテキストに意味があるのだろうと思って削らないままで眺めてみると、先頭のテキスト（＋謎データ）群のサイズがちょうど80bytesでした（"Thanks!"で終わっていたので切れ目はわかりやすかった）。80byte、やたらキリがいい。そんな話を@6f70として、じゃあきっと先頭80bytesは何かしらのヘッダーに違いない！　……ということで、先頭80bytesがヘッダになってるようなファイルフォーマットを探すと……

{{< fluid_imgs "pure-u|/images/2014-07-20-printit-google.png" >}}

……なるほどね（白目）

これほどまでに検索結果のスニペットが欲しい情報をピンポイントで持ってきたことはもはや感動的ですらあるので引用しておくと

<blockquote>
米国のスリーディー・システムズ（英語版）によって開発された三次元CADソフト用の<strong>ファイルフォーマットシステム</strong>。多くのソフトにサポートされ ... バイナリーSTLファイルは<strong>80バイト</strong>の任意の文字列で開始される（通常内容は無視される。ただし、 solid から記載を  ...
</blockquote>

そんなわけで、このファイルフォーマットのバイナリ形式では先頭80bytesは無視されること、このフォーマットはfloatの値がずらーっと並んでいることがわかりました。floatの値が並んでいるだけなら、確かにデータに規則性があって、nullが連続しているのも納得です。

私のマシンにはこれを見られるものがなかったので、Wikipediaの記事の外部リンクにあった3DViewというChromeのアプリを入れてファイルを読むことで解答が得られました。