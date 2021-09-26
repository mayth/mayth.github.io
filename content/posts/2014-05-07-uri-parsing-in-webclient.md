---
title: "MonoのWebClientにおけるURI"
date: 2014-05-07 13:33:03 +0900
author: Mei Akizuru
slug: uri-parsing-in-webclient
tags:
  - .NET Framework
  - Mono
  - C#
aliases:
    - /blog/2014/05/07/uri-parsing-in-webclient/
---

# 発端

発端は[前の記事](/blog/2014/05/07/tkbctf3-miocat/)にあるように、tkbctf3の問題としてmiocatなるものを出してみたのはいいものの、意図とは異なる脆弱性を作り込んで250点問題が超絶ボーナス問題になりましたよ、というお話しです。

# 調査

miocatはC#で書かれており、実際の運用ではMonoランタイムで動いていました。というわけでMonoのソースコードを読めば解決です。やったね。

そういうわけでまずは`WebClient`の実装を読んでみたのですが、怪しい箇所が一発で見つかりました。[WebClient.cs#798](https://github.com/mono/mono/blob/2d573ae1ceac1656f0293cca3736dcb10c28be38/mcs/class/System/System.Net/WebClient.cs#L798)、privateメソッドである`CreateUri(string)`なるメソッドです。`DownloadString(string)`は、その引数をこのメソッドに渡して`DownloadData(Uri)`を呼び出します。

`try-catch`の中で渡されたアドレス（と、`baseAddress`）を元に`Uri`のインスタンスを作って`CreateUri(Uri)`に渡していますが、ここで例外が発生すると`return new Uri(Path.GetFullPath(address))`という恐怖のコードが走ります。

まず例外を発生させる方法ですが、これは簡単でURIとして不正なものを渡してあげればおしまいです。例えば`abc://;/etc/passwd`はhostname部がパース不能なので例外を吐きます。

`System.IO.Path.GetFullPath(string)`というのは名前からお察しの通り、与えられたパスをカレントディレクトリからの相対パスと見なして絶対パスに変換します。ここで、例えばカレントディレクトリが`/home/kogasa`、引数が`http://etc/passwd`だとすると、結果は`/home/kogasa/http://etc/passwd`になります。要するに`http:`というディレクトリの下に`etc`ディレクトリがあって云々、という形になります。つまるところ連続する`/`はひとつにまとめられてしまうわけです。先ほどの例外を吐く例でいけば、`/home/kogasa/abc://;/etc/passwd`になります。

ところでWindowsだとパスに`:`が入ってると厄介なことになりそうというか、[MSDN的には](http://msdn.microsoft.com/ja-jp/library/system.io.path.getfullpath%28v=vs.110%29.aspx)`NotSupportedException`が投げられるべきところだと思うのですが、コレ大丈夫なんでしょうか。ぱっと見ただけだとそれらしいコード見当たらなかったんですが……。

※Windowsで`GetFullPath`に`http://etc/passwd`を与えてみたら、`ArgumentException`で「URLフォーマットには対応していません」みたいなことを言われました。で、`abc://;/etc/passwd`を与えると`NotSupportedException`で「指定されたパスのフォーマットはサポートされていません」と言われました。ちゃんとスキーム見てるんですね。

それはそれとして、そんな感じでフルパスを`Uri`のコンストラクタに与えると、`file:`スキームのURLになって返ってきます。こうなるとただのローカルに対するディレクトリ操作なので、例えば`abc://;/../etc/passwd`にするとフルパスは`/home/kogasa/abc:/etc/passwd`になりますし、もういっこ`../`を足せば`/home/kogasa/etc/passwd`——といった感じで`../`をつけていけば無事に`/etc/passwd`に辿り着けますね、やったね、ということでした。

Monoの実装自体がヤバいのか、それともWindows以外で動かした結果ああなったのかまでは知りませんが、ひとまずそんな感じになりました。Windowsで動かしてたらあの解法は通らなかったのかなぁとかぼんやり思いながらそもそももっとマシな実装しておけばよかったと反省しきり。

それにしても繰り返しになりますが結構このURLとしてのパース失敗時の回復の仕方がヤバい気がするんですが、これは意図的に.NET Frameworkと異なる実装にしているのか特に理由はないけどこうなってるのか、はてさて。

# まとめ

**もっと恐ろしいMonoの片鱗を味わったぜ…**