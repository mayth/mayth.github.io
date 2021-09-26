---
title: "MacのSublime Text 3でもclang使って整形とか補完とかしたい"
date: 2014-02-06 08:56:44 +0900
author: Mei Akizuru
slug: clang-format-on-mac
tags:
    - C/C++
aliases:
    - /blog/2014/02/06/clang-format-on-mac/
---

# clang-formatによるコード整形

MacのCommand Line Toolsには`clang-format`がない。`clang-format`というのはその名前の通り、ソースコードをclangに静的解析させて自動で整形しようというツール。

対応しているコーディングスタイルは次の5つ。

* LLVM
* Google
* Chromium
* Mozilla
* WebKit

また、全く独自のコーディングスタイルを設定することもできるし、あるいはこれらのコーディングスタイルを元に一部を自分好みに変更した設定も可能である。かなり自由。

さて、これ別に自分でコンパイルする必要もなく（LLVMとclang自体が）バイナリ形式で提供されていたりする。便利な世の中だ。[LLVM Download Page](http://llvm.org/releases/download.html)から入手できる。Mac向けは"Clang for Darwin"。

ダウンロードしたファイルを適当なフォルダに展開してパスを通せば`clang-format`が使えるはず。なお`clang-format`以外のものも全部パスが通った場所に置いた場合のシステムの挙動は確かめてない（別にどうってことはないかもしれないし、どっかで何かおこるかもしれない）。

Sublime Textとの連携については公式からプラグインが提供されている（なぜか[ドキュメント](http://clang.llvm.org/docs/ClangFormat.html)には言及がないが……）。

まずはツリーから当該のプラグインを落としてくる。 -> [https://llvm.org/svn/llvm-project/cfe/trunk/tools/clang-format/clang-format-sublime.py](https://llvm.org/svn/llvm-project/cfe/trunk/tools/clang-format/clang-format-sublime.py)

ソースコード冒頭に簡単な説明があるのでそれに従う。まずはこのファイルを`~/Library/Application Support/Sublime Text 3/Packages/User`以下に入れる。次にSublime TextのPreferences -> Key Bindings - Userを選んでキーバインドの設定ファイルを開き次の一行を追加する（説明ではCtrl+Shift+Cになっているのでそのようにしたが適宜変える）。

```json
{ "keys": ["ctrl+shift+c"], "command": "clang_format" }
```

これで`clang-format`にパスを通してあれば動くはずなのだがなぜか動かなかった。`clang-format`がないというエラーメッセージが出ていたので、説明から少し下にある`binary`の値をフルパスに変更して無事に動作した。

なお、このとき使われるコーディングスタイルは`.clang-format`を参照する設定になっている（`binary`のもう少し下に`style`の設定があり、これが'file'となっている）。`style=file`となっているのに`.clang-format`ファイルが存在しない場合、LLVMスタイルが選択される。`clang-format`の`-dump-config`オプションで設定を出力できるのでこれを`.clang-format`として出力させつつ適宜スタイルを修正すると幸せになれる予感がする。


# コード補完

（コードを読み書きする人間を除いて）コードの解釈を一番よく知っているのはコンパイラなんだから、コンパイラにコード補完のバックエンド的な役割をさせようという話。Haxeのコンパイラはこの仕組みを持っていて、コンパイラがサーバーとして動作して、そこにリクエストを投げると型情報やら何やらを返してくれる、という機能がある。あったはず。

同じ事をclangでやろうというお話なのだが、ググると主に紹介されている[quarnster/SublimeClang](https://github.com/quarnster/SublimeClang)はREADMEの初っ端に**Plugin discontinued**と書かれている。オワコン。

そんなわけで同じ作者の後継作たる[quarnster/completion](https://github.com/quarnster/completion)を試す。

まず大前提としてこれGoで書かれているのでGoの環境が必要である。[公式のパッケージ](http://golang.org/doc/install)もあるし、Homebrewでもインストールできる。あと今回の場合はgitとMercurialも必要。

普段Goを書いてないからかもしれないが、Goの開発環境の構築はちょっとクセがあるように見える。環境入れてコンパイラとかにパス通してはいおしまい、とはいかない。[ドキュメント](http://golang.org/doc/code.html)に沿って進める。（Homebrewでインストールしたときもこれ読めというメッセージが出るはず）

まずホームフォルダに`go`フォルダを作る。そして`GOPATH`という環境変数を設定する。ついでに`$GOPATH/bin`にもパスを通しておく。

```bash
$ mkdir $HOME/go
$ export GOPATH=$HOME/go
$ export PATH=$PATH:$GOPATH/bin
```

環境変数の設定は`.bashrc`なり`.zshrc`なりに書いておいた方がよいと思う。ここまで済ませた上で

```bash
$ go get -d github.com/quarnster/completion
```

とするとお目当てのソースコードの他依存しているパッケージのソースコードもごそっと落としてくる（このときにMercurialとgitが必要になる）。

さて、これで`$GOPATH/src/github.com/quarnster/completion`にcloneされている。ビルドするには`build`ディレクトリに入って`make`すればよい。

```bash
$ cd $GOPATH/src/github.com/quarnster/completion/build
$ make
```

ビルドに成功すると同じディレクトリに`completion`というバイナリが生成されている。Sublime Textにプラグインとしてインストールするにはそのまま

```bash
$ ./completion install -st
```

とする。Sublime Textの場所を探し出していい感じにインストールしてくれる（2と3を共存させていても両方にインストールする）。

あとはC/C++でのコーディングをお楽しみください。


# 余談

## ClangComplete

ちなみに別のclangを用いたプラグインに[pfultz2/ClangComplete](https://github.com/pfultz2/ClangComplete)というのがあったが、どうにも動かなかったので諦めた。というのもこのプラグインおおよそLinuxの方しか向いていないようにしか思えない状態だった。一応ある程度のところまで作業したのでメモしておく。

まずこのリポジトリ自体をそのままSublime Textのプラグインディレクトリにcloneする。その後`ClangComplete/complete`ディレクトリに移動して`make`すると見事に失敗する。

Python3.3のヘッダーファイルが見つからないと言っているので`PKG_CONFIG_PATH`を設定する。HomebrewでPython3.3が入っていれば（なければ入れる）、`/usr/local/Cellar/python3/3.3.3/Frameworks/Python.framework/Versions/3.3/lib/pkgconfig`にある（3.3.3の辺りはバージョンによる。これ更新されたらどうなるんだ）。

```bash
PKG_CONFIG_PATH=/usr/local/Cellar/python3/3.3.3/Frameworks/Python.framework/Versions/3.3/lib/pkgconfig
```

次、clangのヘッダファイルがないと言い出す。`Makefile`を編集する。`CLANG_PREFIX`を設定している箇所を消して、上で述べたclang+llvmのバイナリパッケージを展開したディレクトリを指定する。仮に`$HOME/clang`に置いたとすれば`CLANG_PREFIX=$HOME/clang`とする。

次、`std::vector`なんてものはないというエラーが出まくる。そんなアホなと思って`complete.cpp`を見てみると`#include <vector>`がない。適当な場所に追加する。

（ちなみにこれ、gccでは通ったりするのだろうか。少なくとも大学のLinuxマシンに入っていたgcc 4.1.2でもエラーを吐いたが）

次、`-soname`なんてオプションは知らないと言い始める。これは単純に`-soname`を`-install_name`に置換してしまえばよい。 参考: [osx - CMake: Mac OS X: ld: unknown option: -soname - Stack Overflow](http://stackoverflow.com/questions/4580789/cmake-mac-os-x-ld-unknown-option-soname)

次、`-rpath`なんてオプションも知らないと言い出す。これは一旦`-rpath`を削除してしまう（`-Wl,-rpath...`でひとつのオプションなのでこのかたまりを消す。`-Wl`はリンカーに渡すオプションを指定するオプション）。いろいろ探し回った挙げ句、どうもこれを代替する手段はなさそうだった。

これでコンパイルが通る。だが実際にSublime Textを動かしてみると何も起きない。コンソールを確認すると`libclang.dylib`が見当たらずに`libcomplete.so`のロードが失敗している。前の段階で`-rpath`（ランタイムパスの指定）を消してるんだから当たり前だ。これを無理矢理にでも（今回の場合は）`$HOME/clang/lib`を見に行かせる必要がある。

そうして見つかったのが[Dynamic Libraries, RPATH, and Mac OS (Joe Di Pol's Blog)](https://blogs.oracle.com/dipol/entry/dynamic_libraries_rpath_and_mac)という記事だった。これを読んだところ、`install_name_tool`というツールが備わっているのでそれを使って`libcomplete.so`を弄ってしまえばよさそうという感触。ただまぁ使い方も何もさっぱりわからないのでいろいろ試したところ、

```bash
$ install_name_tool -add_rpath $HOME/clang/lib libcomplete.so
```

で`libcomplete.so`のロードに成功した。

が、いざコードを編集しようとするとプラグインが即死する。やはり世の中そう上手くは行かなかった。

もうよくわからなかったしこれ以上格闘してても無駄な気がしたので私はここでcompletionを使うことにした。のでプラグイン即死の理由とかその解決方法がわかったら@maytheplicまでリプください（真顔）。

## clang+llvmのディレクトリ構造

clang+llvmのビルド自体はドキュメントを読めば割と簡単にできるのだけど、あのディレクトリ構造は永遠に理解できないかもしれない。