---
title: "tkbctf4 [bin300] Cheer of CPU"
date: 2014-11-24 04:16:38 +0900
author: Mei Akizuru
slug: tkbctf4-cheerofcpu
tags:
  - CTF
  - tkbctf4
aliases:
    - /blog/2014/11/24/tkbctf4-cheerofcpu/
---

tkbctf4が終了してからずいぶんと時間が経ちましたが皆様いかがお過ごしでしょうか。今更ではありますが[bin300] Cheer of CPUの解説というか、そんなようなものを書いてみようかと。

なお、問題のソースコードと配布されたバイナリはtkbctfのgithubリポジトリにあるので、そちらもどうぞ。 [tkbctf4/bin300_CheerOfCPU at master · tkbctf/tkbctf4](https://github.com/tkbctf/tkbctf4/tree/master/bin300_CheerOfCPU)

# 問題

> Did you hear a cheer of CPU?
>
> The flag is the SHA-256 checksum of the program's output.
>
> sample: `ruby -rdigest/sha2 -e 'puts Digest::SHA256.hexdigest("OUTPUT HERE".strip).downcase'`
>
> [https://s3-ap-northeast-1.amazonaws.com/tkbctf4/cheerofcpu](https://s3-ap-northeast-1.amazonaws.com/tkbctf4/cheerofcpu)

# 概要

問題の内容としてはあるプログラムが渡されるのでそれを調べる、というものです。プログラムは何かしら入力するとそれが所定の文字列と一致するかを調べ、一致していたら何らかのテキストを出力します。そのテキストのSHA256値を取って送りつければ得点となります。これだけ聞くととっても簡単ですが問題はコイツが**64bit Mach-Oバイナリ**ということでした。

# 経緯

元々は「なんか怪しげな言語でバイナリ吐いて読ませるような問題を作ろうぜ」というのが出発点です。様々な言語が候補に現れては消えていきましたが、私がちょうどMacを持ってるということでSwiftに白羽の矢が立ちました。（ちなみにこの発想から作られたもうひとつの問題は"rakuda"です。あの問題、なんか別ゲーになってる気がしますけど）

たださすがに当初はx86\_64 Mach-Oで出すという想定はしていませんでした。が、コマンドラインアプリケーションとして作ってしまったのでiOSアプリにすることもできず、かといってSwiftコンパイラがそもそもx86環境向けのバイナリを吐けるようにできていないので、まぁそういう問題もありかなみたいな判断で結局x86\_64 64bit Mach-Oで出題しました。

たださすがにMac OS X 10.10 (Yosemite) SDK使ったのはやりすぎだったかなと反省しております（とはいえ、私の環境には1つ前のバージョン、すなわち10.9 MavericksのSDKまでしか入ってなかったわけですが）。

# プログラムに関して

というわけではじめてのSwiftかいはつ、となったんですがなんかSwiftの記法が結構キモくて大変でした（※個人の感想です）。あとSwiftって識別子に絵文字が使えることで有名ですが、なんかどっかで関数名見えたら嫌だなぁとか思ったので絵文字を使ったところgithubで見事に化けました。実際はこんな感じの開発風景でした。

{{< fluid_imgs "pure-u|/images/20141124_cheerofcpu_sourcess.png|screenshot of Cheer of CPU development environment" >}}

なんとなく格納されてるデータとか関数の役割とかが見えてきますね！　見えてきませんか？　見えてくるんでしょう？　……そうなんでしょ？

文字通りにクソみたいな見た目のコードは置いておいてその内容について触れておきます。内部でテキストデータは基本的に`Byte`(`UInt8`)の配列と`Int`の配列のタプルで保持されています。`strings`対策ですね。タプルの1つ目の要素がシャッフルされ、暗号化された状態のテキストのバイト列、2つ目の要素がシャッフル順です。シャッフルと書きましたが、テキストのバイト列はシャッフルされた後に暗号化された状態で保持されており、元の順番に復元するための情報が2つ目の要素にある配列、ということになります。暗号化は単純なxorですが、1要素暗号化する度にキーが変化するようになっています。その辺はソースコードを見て頂ければ。なお、最終的に出力されるテキストデータだけは、正解のキーを元にして生成された暗号化鍵と初期化ベクタを用いて、ChaCha20で暗号化された状態で保持しています。ちなみにChaCha20採用の理由ですが、CryptoSwiftに入っていたから以外に特に理由はないです。

動作としては概要で述べたもので、起動すると入力待ちになるので「キー」を入力します。これを内部で保持しているデータと比較し、一致していればそのキーを用いて鍵と初期化ベクタを生成し、テキストデータを復号化して出力します。

# 作ってみた・出してみた感想とか諸々

問題の難易度的には明らかに「プログラムが動く（または解析出来る）環境を用意出来るか否か」がハードルという感じでしたね。動かせる環境(Yosemite)があれば総当たりで行ける問題だなぁとか元々思ってたので事実上CTFプレイヤーにおけるMac普及率調査みたいになっていた感じもあります。別にApple信者でもなんでもないのでMac買ってくださいとは言いませんが。あるいはIDA Pro（無料版でない）があれば解析可能だったかと思います。私は持ってませんがopがやってたのでたぶん大丈夫だったんでしょう、たぶん（ていうかtkbctf4のバイナリ問はIDA Pro Freeで解析可能な問題の方が少なかったという異常事態でしたね）。

皆さんはこの無駄に高いハードルを超えて（Macを買うにしろIDA Proを買うにしろ『素人が購入するとは考えにくい』お値段故、素人ではないであろう皆さんでも難しいでしょう）「CPUの歓声」を聞くことは出来たでしょうか。

ちなみに、これ出題してから"tkbctf"とか色々なワードでTwitterで検索かけてまして、64bit Mach-Oバイナリに思わず「歓声」を上げる皆さんを見て爆笑してたりしました（こういうのを性格が悪いと言います）。

あとタイトルの元ネタの鮮度がちと古かった気がするなぁという感もあります。ソースコード上げたリポジトリのREADMEにも書きましたが、皆さん覚えているでしょうか。時は5ヶ月前、2014年6月。WWDC 2014で世にSwiftが発表され、The Swift Programming Languageが公開された後にTwitterを席巻した、あの衝撃の発言を。

<blockquote class="twitter-tweet" data-cards="hidden" lang="ja"><p>Swiftの関数はHaskell風。これはいい。マシン語が透けて見える。CPUの歓声が聞こえてきそうだ <a href="http://t.co/tfWwKe5e03">pic.twitter.com/tfWwKe5e03</a></p>&mdash; Ryo Shimizu (@shi3z) <a href="https://twitter.com/shi3z/status/473627881055485952">2014, 6月 3</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

（もちろんこの前後にも**とても素晴らしい発言**があるわけですが）

Swiftの関数はHaskell風、マシン語が透けて見える、CPUの歓声が聞こえてきそう——もう見るだけで頭がクラクラしてきそうな圧倒的で革新的で先進的で最も優れた表現力を持ったこのツイートに感銘を受け、今回の問題はSwiftで書かれているということで、このツイートをリスペクトして問題名にしました。このような素晴らしいツイートを世に送り出してくださったRyo Shimizu(@shi3z)氏にはこの場を借りて感謝の意を述べさせて頂きます。

しかしながら、個人的に「マシン語が透けて見える」というとこちらの方を推しておきます。

<blockquote class="twitter-tweet" lang="ja"><p>マシン語が透けて見える。CPUの歓声が聞こえてきそうだ <a href="http://t.co/drJMSTIdFQ">pic.twitter.com/drJMSTIdFQ</a></p>&mdash; 秋弦めい☂小傘ちゃんかわいい (@maytheplic) <a href="https://twitter.com/maytheplic/status/473701724574605313">2014, 6月 3</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

# 最後に

**小傘ちゃんかわいい。**