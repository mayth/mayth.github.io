---
title: "SECCON 2014 Online Qualification (December) write-up"
date: 2014-12-07 22:11:39 +0900
author: Mei Akizuru
slug: seccon2014-online-winter
tags:
  - CTF
  - SECCON
aliases:
    - /blog/2014/12/07/seccon2014-online-winter/
---

# Welcome to SECCON (Start 100)

> The answer is "SECCON{20141206}".
>
> 答えは、「SECCON{20141206}」です。

驚くべきことに問題ページに答えが書かれている。なんと楽な問題なのだろう。

Answer: `SECCON{20141206}`

# jspuzzle (Web 100)

> jspuzzle.zip
>
> You need to fill in all blanks!

`jspuzzle.zip`を展開すると`q.html`と`sha1.js`がある。`sha1.js`はJavaScriptでSHA-1のハッシュ値を計算するライブラリの模様。本体は`q.html`。

HTMLファイルを開くと穴あきになったJavaScriptのコードと、空いている箇所に埋めるピースとなる語が表示されている。目標はピースをはめていって、`alert(1)`を実行するコードにすること。フラグの値は埋めたピースから計算されたSHA-1ハッシュ値。問題文には「全ての空欄を埋めよ」とあるので、ちゃんと全部埋める。当然ながら一度使ったピースは二度使えない。

コードは次の通り(`"???"`が空欄の箇所)。

```js
"use strict";

({"???" :function(){
    this[ "???" ] = (new Function( "???" + "???" + "???" ))();
    var pattern = "???";
    var r = new RegExp( pattern );
    this[ r[ "???" ]( pattern ) ][ "???" ]( 1 );
}})[ "???"[ "???" ]() ]();
```

ピースは次の通り。

* fromCharCode
* indexOf
* match
* this
* new
* null
* charAt
* alert
* constructor
* /*^_^*/
* return
* pattern
* toLowerCase
* exec
* eval
* debugger
* function
* ^[w]$

外側から見ていく。連想配列を生成して、その連想配列のある要素を関数として呼び出すコードがある。値は`function () { ... }`で固定で、キーの方が抜けている。また要素を取り出すときに`"???"["???"]()`をキーにしている。書き換えれば`"???".someMethod()`なので、後者の方は`String`に対するメソッドだと推測出来る。また、最初の空欄とこのメソッド呼び出しの結果が一致しなければならないから、最初の空欄が`function`、最後の2つの空欄が`Function`と`toLowerCase`となる。

本題の内側の方。4行目は何かしらの関数を生成してそれを実行した結果をこの連想配列に代入している。ということは、`new Function("...")`の中身は何かを返さねばならないので、3つの空欄のうち最初は`return`である。また7行目を見ると最終的にここで返した何かに対してメソッド呼び出しを行っている。引数が`1`なので`alert`が来ることは明らかである。よってここは`window`を返したい。だが3つの空欄は単純な文字列連結なので空白がない。これでしばらく悩んだが、よく見ると`/*^_^*/`はコメントである。まさかと思って2番目にこれを入れて、3番目に`this`を入れたところ、見事に`window`が返ってきた。ちなみに`this`を入れたのは他に選択肢がなかったからで、JavaScriptの`this`の仕様はさっぱり理解してない、というか出来る気がしない。なんで左辺の`this`は連想配列自身なのに右辺の関数内の`this`は`window`（たぶん外側で関数呼び出しを実行してる時点での`this`）なんだ…。ここまで固まったついでに5行目の2番目の空欄が`alert`であることも確定。

さて、7行目の最初の空欄だが、`r`はRegExpのインスタンスなのでここに入れられるのは`exec`か`constructor`くらいしかない。`constructor`入れたところで`this[/pattern/][alert](1)`になって意味不明なので`exec`を入れる。そうすると、4行目に先ほどの関数を代入した先のキーと`r.exec(pattern)`の結果が一致しなければならない。だが先ほど使ったような`function`と`"Function".toLowerCase()`の手は使えない。ところで、このとき調べて初めて知ったのだが、`test["null"] = "hoge"; console.log(test[null])`は`hoge`を出力する。マジかよと思って実行して唖然とした。JavaScriptヤバすぎるのでゎ。……でなんでそんな話をしたかというとちょうどピースに`null`が入っていて、かつ`pattern = "^[w]$"`とすると`r.exec(pattern)`は`null`を返すのである。

——というわけで空欄に`null`、`^[w]$`を埋めて完了。`alert(1)`が実行されるのを確認してフラグを送信して終了。

`this["null"] = ...`の部分は@yyuがいなければ無限に悩んで死亡していた。連想配列のキーの比較どうなってるんだよマジ。

Answer: `SECCON{3678cbe0171c8517abeab9d20786a7390ffb602d}`

# Easy Cipher (Crypto 100)

> 87 101 108 1100011 0157 6d 0145 040 116 0157 100000 0164 104 1100101 32 0123 69 67 0103 1001111 1001110 040 062 060 49 064 100000 0157 110 6c 0151 1101110 101 040 0103 1010100 70 101110 0124 1101000 101 100000 1010011 1000101 67 0103 4f 4e 100000 105 1110011 040 116 1101000 0145 040 1100010 0151 103 103 0145 1110011 0164 100000 1101000 0141 99 6b 1100101 0162 32 0143 111 1101110 1110100 101 0163 0164 040 0151 0156 040 74 0141 1110000 1100001 0156 056 4f 0157 0160 115 44 040 0171 1101111 117 100000 1110111 0141 0156 1110100 32 0164 6f 32 6b 1101110 1101111 1110111 100000 0164 1101000 0145 040 0146 6c 97 1100111 2c 100000 0144 111 110 100111 116 100000 1111001 6f 117 63 0110 1100101 0162 0145 100000 1111001 111 117 100000 97 114 0145 46 1010011 0105 0103 67 79 1001110 123 87 110011 110001 67 110000 1001101 32 55 060 100000 110111 0110 110011 32 53 51 0103 0103 060 0116 040 5a 0117 73 0101 7d 1001000 0141 1110110 1100101 100000 102 0165 0156 33

十進法の値と二進法の値と八進法の値と十六進法の値が入り乱れている気がするテキスト。

```ruby
class String
  def parse
    case
      when self.start_with?('0')
        self.to_i(8)
      when self =~ /\A[01]+\z/ and self.length > 3
        self.to_i(2)
      when self =~ /[a-f]/
        self.to_i(16)
      else
        self.to_i(10)
    end
  end
end

data = gets.strip.split(' ')
puts data.map(&:parse).map(&:chr).join
```

Answer: `SECCON{W31C0M 70 7H3 53CC0N ZOIA}`

# Choose the number (Programming 100)

> nc number.quals.seccon.jp 31337
>
> sorry fixed URL

ncすると数列と問題が流れてくる。サンプルは以下の通り。

```
-5, -9
The minimum number? -9
6, 7, -4
The minimum number? -4
1, -7, 7, 1
The maximum number? 7
6, 8, -5, -4, -5
The minimum number? 8
-3, -5, -8, -6, -1, 0
The maximum number? 0
-1, 1, 4, 2, -6, -6, 0
The maximum number? 4
0, 4, -2, 1, 9, -9, 7, -4
The maximum number? 114514
Wrong, bye.
```

与えられた数列に対して、その中での最大値もしくは最小値を答える。Rubyで入力を`,`で区切って数値化して`Enumerable.(max|min)`で答えるプログラムを書いた。入出力のデバッグで10分は取られてすごくつらい。

```ruby
require 'socket'

SERVER_URI = 'number.quals.seccon.jp'
SERVER_PORT = 31337
LOG_NAME = 'comm.log'

def read_question(sock)
  s = ''
  while true
    c = sock.getc
    if c == '?'
      s << c
      s << sock.getc # whitespace
      break
    elsif c.nil?
      break
    end
    s << c
  end
  s
end

begin
  sock = TCPSocket.open(SERVER_URI, SERVER_PORT)
  file = File.open(LOG_NAME, 'a')

  num_str = ''
  qstr = ''

  while true
    num_str.clear
    qstr.clear

    num_str = sock.gets
    if num_str.include?('bye')
      fail 'connection closed by host'
    end

    qstr = read_question(sock)
    file.puts num_str
    file.print qstr
    file.flush

    nums = num_str.split(',').map(&:strip).map(&:to_i)
    qstr.strip!
    ans =
      case qstr
      when 'The minimum number?'
        nums.min
      when 'The maximum number?'
        nums.max
      else
        fail 'unknown question'
      end
    file.puts ans
    sock.puts "#{ans}\n"
    sock.flush
    file.flush
  end
rescue => e
  puts 'something went wrong!'
  p e
  puts 'num_str = ' + num_str unless num_str.empty?
  puts 'qstr = ' + qstr unless qstr.empty?
ensure
  file.close
  sock.close
end
```

ちなみに`sock.puts`で答えを投げてるところに改行文字を入れてなかったのでバグってた。そんなのアリかよ(`puts`はそもそも改行を最後に入れるはずでゎ……)。しかしWiresharkで通信見たら問題の送信タイミングがおかしくて、それで気付いたのでやはりWireshark最強。

# Get from curious "FTP" server (Network 300)

> ftp://ftpsv.quals.seccon.jp/

Chromeで見に行くとCOMMAND_NOT_SUPPORTEDとか言われてダメ。よくわからないのでとりあえず[FTPコマンド一覧](http://ja.wikipedia.org/wiki/FTP%E3%82%B3%E3%83%9E%E3%83%B3%E3%83%89%E3%81%AE%E4%B8%80%E8%A6%A7)を片手にtelnet。

ログインしろと言われるがanonymousしかないと言われるので`USER anonymous`で接続。とりあえず`PWD`してみると`/`にいる。じゃあ`LIST`してみるかと思って`LIST`すると"not implemented"と言われる。そんなFTPサーバーがあるか。仕方ないので片っ端からコマンドを試そうとする。一覧の一番上は`ABOR`だったけど、さすがに何も転送してないのに`ABOR`しても仕方ないと思って、その次の`ACCT`にしてみる。そうすると`PORT`か`PASV`をしろと言われる。え、アカウント情報の転送って転送用のコネクションいるんですか、と思いながら電卓片手に`PASV`を叩いて、別のターミナルで指定のポートにtelnet（なんでncじゃなかったんだろう）。一応念のためもう一度`LIST`してみたけど相変わらず未実装らしいので`ACCT`を投げると、なぜか`LIST`相当の処理が走って別ターミナルにファイル一覧が流れてきた。何が起きたかさっぱりわからないが、「`key_is_in_this_file_...`」みたいなファイルがいるらしいので、`RETR`コマンドでそのファイルを持ってくる。

> Answer: `SECCON{S0m3+im3_Pr0t0c0l_t411_4_1i3.}`

参考までに通信内容。

```
% telnet ftpsv.quals.seccon.jp 21
Trying 133.242.224.21...
Connected to ftpsv.quals.seccon.jp.
Escape character is '^]'.
220 (vsFTPd 2.3.5(SECCON Custom))
USER anonymous
331 Please specify the password.
PASS pass
230 Login successful.
PWD
257 "/"
LIST
502 LIST not implemented.
ACCT
425 Use PORT or PASV first.
PASV
227 Entering Passive Mode (133,242,224,21,252,27).
LIST
502 LIST not implemented.
ACCT
150 Here comes the directory listing.
226 Directory send OK.
PASV
227 Entering Passive Mode (133,242,224,21,255,82).
RETR key_is_in_this_file_afjoirefjort94dv7u.txt
150 Opening BINARY mode data connection for key_is_in_this_file_afjoirefjort94dv7u.txt (38 bytes).
226 Transfer complete.
```

別ターミナルの方。

```
% telnet ftpsv.quals.seccon.jp 64539
Trying 133.242.224.21...
Connected to ftpsv.quals.seccon.jp.
Escape character is '^]'.
-rw-r--r--    1 0        0              38 Nov 29 04:43 key_is_in_this_file_afjoirefjort94dv7u.txt
Connection closed by foreign host.

% telnet ftpsv.quals.seccon.jp 65362
Trying 133.242.224.21...
Connected to ftpsv.quals.seccon.jp.
Escape character is '^]'.
SECCON{S0m3+im3_Pr0t0c0l_t411_4_1i3.}
Connection closed by foreign host.
```

# Making a bot (Programming 0)

この辺で解けそうな問題がなくなり人権を失ったが、@re_Ordが問題を解いたというので、Slack上でいいね！ができるようにbotに手を入れ始めた。つまるところ別のことをし始めた。

元々hubotで（主に@opが使う）違法語句に対して全自動で:fu:を投げ付けるbotを書いていたのでそこに追加する形で実装した。永続化ストレージはなんかRedisの例ばかりだったのでとりあえずRedisにした。永続化ストレージをくっつけたついでに、違法語句を使用したときにお前の罪を数えろと言わなくていいようにkarmaポイントを記録するようにした。これで積極的に（主に@opに）罪の精算を迫っていこうと思う。最初の+1は@re_Ordに捧げられた。+1。

ただ違法語句を使用したときに:fu:が飛ぶという仕様のせいで、botの名前をkogasa-chanにできないしアイコンに小傘ちゃんを使うこともできなくなった。あのかわいい小傘ちゃんは中指など飛ばさないのである。悩ましいことである。