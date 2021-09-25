---
title: "YosemiteでSublime Text 3 + LaTeXToolsを使ったらPDF出てこない話"
date: 2014-10-17 17:56:46 +0900
author: Mei Akizuru
tags:
  - Yosemite
  - Sublime Text
  - LaTeX
aliases:
    - /blog/2014/10/17/sublime-latex-yosemite/
---

覚え書き。

今日公開されたMac OS X Yosemite (10.10)に早速更新したところ、Sublime Text 3 + LaTeXToolsの環境でLaTeXをビルドしてもPDFが出力されなくなった。

この問題はYosemiteがbetaの時点でアップグレードして報告した猛者がいた。[LaTeXTools on OS X 10.10 · Issue #401 · SublimeText/LaTeXTools](https://github.com/SublimeText/LaTeXTools/issues/401)

> opened this issue on 5 Jun

（白目）

症状としては上述の通り。ビルドを実行したときにコンソールへ吐き出されているログはこんな感じ。

```
Welcome to thread Thread-13
['latexmk', '-cd', '-e', "$latex = 'uplatex %O -interaction=nonstopmode -synctex=1 %S'", '-e', "$biber = 'biber %O --bblencoding=utf8 -u -U --output_safechars %B'", '-e', "$bibtex = 'upbibtex %O %B'", '-e', "$makeindex = 'makeindex %O -o %D %S'", '-e', "$dvipdf = 'dvipdfmx %O -o %D %S'", '-f', '-norc', '-gg', '-pdfdvi', 'report.tex']
Finished normally
12
Exception in thread Thread-13:
Traceback (most recent call last):
  File "./threading.py", line 901, in _bootstrap_inner
  File "/Users/mayth/Library/Application Support/Sublime Text 3/Packages/LaTeXTools/makePDF.py", line 147, in run
    data = open(self.caller.tex_base + ".log", 'rb').read()
FileNotFoundError: [Errno 2] No such file or directory: '/Users/mayth/Documents/report.log'
```

`report.{pdf,log}`。察して。

それはともかく、どうやらこれは[YosemiteでデフォルトのPATHの値が変わっているのが原因](https://github.com/SublimeText/LaTeXTools/issues/401#issuecomment-59058434)らしい。そこで、肝心のコマンドを呼んでいるところでPATHを追加してあげればよい。

[LaTeXTools on OS X 10.10 · Issue #401 · SublimeText/LaTeXTools](https://github.com/SublimeText/LaTeXTools/issues/401#issuecomment-59080557)から引用すると

> proc = subprocess.Popen(cmd, stderr=subprocess.STDOUT, stdout=subprocess.PIPE,
env=os.environ)

これは`makePDF.py`の中に含まれている。Macでは`makePDF.py`は以下のパスにある。

```
$HOME/Library/Application Support/Sublime Text 3/Packages/LaTeXTools/
```

パス辿るのが面倒ならPreferences -> Browse Packagesを使えばPackagesフォルダがFinderで開かれるので、その中のLaTeXToolsを見ると存在するはず。

現時点では当該の記述は95行目にある。その行に上記引用のように、`env=os.environ`を追記すると上手く動くようになった。