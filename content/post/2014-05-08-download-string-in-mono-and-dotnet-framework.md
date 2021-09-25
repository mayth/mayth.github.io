---
title: "結局Monoと.NETの挙動の違いはなんだったのか"
date: 2014-05-08 06:49:41 +0900
author: Mei Akizuru
tags:
  - .NET
  - Mono
aliases:
    - /blog/2014/05/08/download-string-in-mono-and-dotnet-framework/
---

続・アレな文字を`WebClient.DownloadString(String)`に渡すとローカルのファイルが読める

ここ2つの記事でMonoの`WebClient.DownloadString(string)`にアレな文字列渡すとローカルファイルを落としてきてしまうという挙動について調べてたわけですが、よくよくスタックトレースを見てみると、.NET Frameworkでも`GetUri`というメソッドを経由して`Path.GetFullPath`が呼ばれていたことがわかりました。

そんなわけで`Path.GetFullPath`の挙動を見てみると、`http://../../../../etc/passwd`といったような文字列を与えたときに.NETとMonoで次のような挙動の違いが見られました。

* .NET Frameworkは「URIフォーマットはサポートしていない」というメッセージと共にArgumentExceptionが投げられる
* Monoはそのままフルパスに変換する

.NET上で同じことをしても`DownloadString(string)`がここまで問題にしてきた挙動をしなかったのは、ここで例外を吐いて止まっていたから、というだけのことだったわけです。

# スキーム

ところでスキームをhttpじゃなくて適当な何かに変えたらどうなるんだろうと思って試してみました。

与える文字列を`abc://../../../../etc/passwd`といったように、実在しないような適当なスキームに変えて同じプログラムを動かしたところ、.NETではUriとしてのパースに成功しました。httpスキームのときは最初の部分をhostnameとして認識していたので、恐らくスキームを見てフォーマットを認識してるんでしょう。

さて、.NETにおいてはパースの結果`abc://../etc/passwd`になりました。なぜか`../`の部分がひとつにまとめられていましたがこれは一体どういう挙動なんでしょう。それはともかく、この結果を踏まえた上で同じ文字列を`WebClient.DownloadString(string)`に渡すと、今度は「そんなURIプリフィックスは知らん」とNotSupportedExceptionを投げられました。`WebRequest.Create`の中から呼ばれているようなので、前述の`GetUri`などは成功しているようです（というか、new Uriが成功するんだからそら成功するだろう）。で、[System.Net.WebRequest.Create(String)](http://msdn.microsoft.com/ja-jp/library/bw00b1dc%28v=vs.110%29.aspx)を見ると、やはり渡されたURIのスキームに対応するものがない、という例外でよさそうです。どんなURIが渡されてもこれが呼ばれるとするなら、`http(s)://`、`ftp://`、`file://`のいずれにも該当しないURIは常に弾かれることになります。

Monoの場合、まず`new Uri(String)`が`UriFormatException`で失敗します。ということは前の記事で述べた通り`Path.GetFullPath`が呼ばれることになり、やはりこの場合でもローカルのファイルが読めてしまいます。

# まとめ

結局何がこの挙動の違いを生み出していたのかというと以下の2点だと考えられます。

* Monoの`new Uri(String)`が未知のスキームを持つURIに対して失敗する（.NETは成功する）
* Monoの`Path.GetFullPath(String)`がURIであるような文字列に対して成功する（.NETは失敗する）

とりあえずバグレポートも書いたのでこの件は一段落ということでいいんじゃないんでしょうか……（遠い目）

（バグレポート、type="text"なフィールドでEnter叩いちゃって途中送信されて慌てて削除する方法を探してみるも見当も付かず、結局コメントで「途中送信しちゃった許してくださいお願いします何でもしますから」って言いながらレポート書き直したのは内緒だぞっ）

あと、整理のために`DownloadString(String)`の処理の流れを書いておきます。

## .NET

### 既知のスキームを持つ不正なURI

given: `http://../../etc/passwd`

1. `GetUri`が呼ばれる
2. たぶん内部的に`new Uri(String)`して失敗する
3. たぶんその結果`Path.GetFullPath(String)`が呼ばれる
4. `Path.GetFullPath(String)`がArgumentExceptionを投げる ("URI formats are not supported.")

### 未知のスキームを持つ不正なURI

given: `abc://../../etc/passwd`

1. `GetUri`が呼ばれる
2. たぶん内部的に`new Uri(String)`して成功する
3. 成功したのでその結果をそのまま返す
4. `WebRequest.Create`が呼ばれる
5. `WebRequest.Create`が未知のスキームに対応できずNotSupportedExceptionを投げる

## Mono

### 既知のスキームを持つ不正なURI

given: `http://../../etc/passwd`

1. `CreateUri`が呼ばれる
2. `new Uri(String)`して失敗する
3. `Path.GetFullPath(String)`が呼ばれる
4. `Path.GetFullPath(String)`が成功し、結果を返す (e.g. `/home/etc/passwd`)
5. その結果を`new Uri(String)`に渡す (結果`file:///home/etc/passwd`なUriが返る)
6. それを取得する (この場合は（たぶん）そのファイルがないので例外を吐く）

### 未知のスキームを持つ不正なURI

given: `abc://../../etc/passwd`

1. `CreateUri`が呼ばれる
2. `new Uri(String)`して失敗する
3. `Path.GetFullPath(String)`が呼ばれる
4. `Path.GetFullPath(String)`が成功し、結果を返す (e.g. `/home/etc/passwd`)
5. その結果を`new Uri(String)`に渡す (結果`file:///home/etc/passwd`なUriが返る)
6. それを取得する (この場合は（たぶん）そのファイルがないので例外を吐く）

※.NETとの対比で両方書いたが、Monoの場合いずれも処理の流れは全く同じ