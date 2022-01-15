---
title: "Octopress -> Hugoお引っ越し記録"
date: 2022-01-15T20:23:00+09:00
author: Mei Akizuru
slug: octopress-hugo-migration
tags:
    - tech
    - octopress
    - hugo
    - githubpages
---

[前の記事]({{< ref "posts/2021-09-26_site_migration.md" >}})で引っ越し記録を書くと言って結局4ヶ月ほど放置してしまったけど一応記録。

## 背景

元々 `tech.aquarite.info` はOctopressで生成したものをGitHub Pagesに乗っけていて、 `aquarite.info` は手書きのHTMLを契約しているVPSでホストしていた。まず手書きで全部管理するのが超絶しんどい、ぶっちゃけ分ける理由があんまりない、などの理由でこれらを統合することにした。
これと同時に、Octopressはとうに更新が止まっていること、Octopressのリポジトリをcloneしてきてそこに手を加えるスタイルがやっぱり気持ち悪いといった理由でOctopressから別のstatic site generatorに移ろうと考えていた。で、色々と調べてみたがHugoにした。

{{< note >}}
Octopress 3.0なるものがあって、そちらではこの「リポジトリをcloneしてくる」というスタイルではなくなってるっぽい。ただリリースが2015年1月ということは、整理前のブログを作った当初存在していない。あとそちらも最終コミットが6年前になっていてメンテナンス状況が不明である。
{{< /note >}}

Hugoを選んだ理由には前の記事に書いた通り `urandom.team` の方で使ってたから、というのが大きい。別に新しいものを使うモチベーションがあんまなかったともいう。ちなみに、あっちも実のところこちらのサイト整理前と同様にブログはHugoでapex domainの方は手書きという感じになっている。正直アレも統一したい。

## 記事のお引っ越し

Octopressを使ってるときは前述の通りOctopressそれ自体のリポジトリをcloneしてきて、さらにそのmasterを`source`ブランチに変更していた。では`mayth/mayth.github.io`の`master`ブランチはどうなっているかというと、GitHub Pagesとして公開される内容になっている。なので用事があるのは`source`ブランチということになる。

先にHugoの方で初期設定を済ませておく。一旦GitHub Pagesのリポジトリ(`mayth/mayth.github.io`)をディレクトリごとコピーして、新しい方は`mayth.github.io.new`みたいな名前にする。これはリポジトリを作るとかではなくてあくまでローカルのディレクトリの話。

Octopressでは記事は`source/_posts/`以下に格納されていて、各記事はMarkdownで書かれている。HugoでもMarkdownを使うので、まずはこれをそのままコピーしてくる。Hugoでの記事は`content/posts/`以下に格納する。

```
$ cp mayth.github.io/source/_posts/*.markdown mayth.github.io.new/content/posts/
```

記事のMarkdownの先頭にFront MatterというYAMLで書かれたヘッダみたいなものがあって、OctopressもHugoもこれを解釈する。まずはこのヘッダの内容を調整する。例えば"DatabaseRewinder with Rails 4.2 & PostgreSQL"という記事だと、元は次のような内容だった。

```yaml
layout: post
title: "DatabaseRewinder with Rails 4.2 & PostgreSQL"
date: 2015-03-12 18:49:02 +0900
comments: true
categories:
  - Ruby on Rails
  - PostgreSQL
```

これが色々弄った結果次のようになった。

```yaml
title: "DatabaseRewinder with Rails 4.2 & PostgreSQL"
date: 2015-03-12 18:49:02 +0900
author: Mei Akizuru
slug: database-rewinder-with-rails-4-2
tags:
  - Ruby on Rails
  - PostgreSQL
aliases:
    - /blog/2015/03/12/database-rewinder-with-rails-4-2/
```

差分はこんな感じ。

* 消えたもの
    * `layout`
    * `comments`
    * `categories`
* 増えたもの
    * `author`
    * `slug`
    * `tags`
    * `aliases`
* 変わってないもの
    * `title`
    * `date`

まぁ概ね変わったとみてよいだろう。

`author`はひとりしかいないので全ファイルに機械的に追記、`comments`は一律消去、`categories`は`tags`になっただけなのでこれは単純なリネームでよい（「タグ」と「カテゴリ」という意味的には本当はおかしな話だが）。問題は`slug`と`aliases`である。

まずサイト整理にあたって、次のようにURLを変更することにした。

```
old: tech.aquarite.info/blog/:year/:month/:day/:slug
new: aquarite.info/blog/:year/:month/:slug
```

要するに記事のパスから`:day`、日付を消した。この設定自体はHugoの`config.toml`に次のように設定すればできる。

```toml
[permalinks]
  posts = '/blog/:year/:month/:slug'
```

ただ、この状態でサイト生成してみると、古い記事のリンクが`/blog/2015/03/2015-03-12-database-rewinder-with-rails-4-2`みたいになってしまう。これはOctopressとHugoで"slug"として認識する部分が違うことによる。どちらもファイル名を基準にしているのだが、Octopressはファイル名を`[year]-[month]-[day]-[slug].markdown`というように解釈する。つまり前半の日付部分は日付部分として取り除く。一方でHugoは拡張子を除いたファイル名全体をslugだとみなす。そういうわけで、上のpermalinksの設定だけではパスに日付部分と別にslugの一部として日付が出てくるわけだ（その辺のHugoの仕様は[Content Organization](https://gohugo.io/content-management/organization/)に書いてある）。

それでは冗長なので、Hugoでは明示的にslugを指定することになる。ただファイル名からいちいちコピペしてくるのはあまりにつらいので、適当なRubyのスクリプトを書いた（実際には後述の内容も含めたスクリプト）。スクリプト自体はもう手元にないが、確か

1. globであるディレクトリの下のMarkdownファイルを取得
2. 各ファイルの名前に対して`/\d{4}-\d{2}-\d{2}-(.+?).markdown`みたいな正規表現でマッチさせてslugを取得
3. 取得したslugを適当な行数に差し込んで保存

みたいな流れだったと思う。シェルスクリプトとかsedでやる気力はなかった。

で、`aliases`の方は何かというと見ての通りエイリアスである。エイリアスで指定されたパスにアクセスされると、それが設定されている元の記事にリダイレクトされる。サイトを生成してみると、エイリアスに設定されたパスに次のような内容の`index.html`が置かれている。`<meta http-equiv="refresh">`を使ってリダイレクトさせる内容である。

{{< highlight html >}}
<!DOCTYPE html><html><head><title>https://aquarite.info/blog/2015/03/database-rewinder-with-rails-4-2/</title><link rel="canonical" href="https://aquarite.info/blog/2015/03/database-rewinder-with-rails-4-2/"/><meta name="robots" content="noindex"><meta charset="utf-8" /><meta http-equiv="refresh" content="0; url=https://aquarite.info/blog/2015/03/database-rewinder-with-rails-4-2/" /></head></html>
{{< /highlight >}}

これは古いURLでアクセスされることを考慮したもので、いやこのブログそんなにアクセスないだろ、とは思いつつもURLの永続性維持は命より重い[要出典]のでエイリアスも設定してある。

古いURLのパス部分もファイル名から分かるので、先ほどと同様に適当なRubyのスクリプトを書いた。ファイル一覧を取ってきて正規表現でファイル名から日付とslugを取得するところまでは同じで、`slug`の代わりに`aliases`を追加する。


## 設定の微調整

```toml
[markup]
  [markup.goldmark]
    [markup.goldmark.renderer]
      unsafe = true
```

これを入れておかないと生のHTMLが解釈されない。HTMLを直接書いている箇所としてはTwitterからのツイート埋め込みがあった。

組み込みshortcodeの`tweet`を使えば簡単に埋め込めるし上記のような設定は不要なのだが、埋め込んだツイートが消えている場合、エラーを吐いてレンダリングを中止してしまう（レンダリング時にTwitterにリクエストを投げてblockquoteの中に入れるツイート本文を取得してるんだと思う）。これについては次のような設定をしておくと回避できる。

```toml
ignoreErrors = ["error-remote-getjson"]
```

これでとりあえずモノは出てくるようになるが、今度はツイートの埋め込みがそもそも無かったことにされてしまう。そうするとある日突然虚空に向かって言及する記事みたいになりかねないので、HTMLの埋め込みを許可した上で記事を書いた時点で引用してくるという運用にしている。この場合、ツイートが存在しなくても少なくともツイート本文は残るので、意味不明な言及になったりはしない。


## 静的ページの作成

Static site generatorなんだから全部静的だろうってそうではなく、ここのAboutみたいな独立したページの話。

Octopressの時にはそれっぽいページは作ってなかったが、今回は元々静的なサイトだった`aquarite.info`を統合した関係で作成した。

といっても特に何か設定が必要なわけではなく、単に`content/`以下に例えば`foo.md`という名前でMarkdownファイルを置いておくと`/foo`でアクセスできるようになっている。今回の場合は`content/about.md`としている。これで`aquarite.info/about/`で見られるようになる。


## 自動デプロイ

これまでは手動で実施していた。この頃まだGitHub Actionsなるものはない。

1. 手元でOctopressのビルドを走らせる
2. 生成されたファイルを`master`ブランチにコミットしてpush
3. `source`にも変更をコミットしてpush

ブランチ切り替えて云々とかが面倒過ぎるので、変更（したソース）をpushしたらGitHub Actionsでビルドして公開されるようにした。

こちらも特に難しいことはない。公式の説明([Host on GitHub](https://gohugo.io/hosting-and-deployment/hosting-on-github/))にある定義をそのまま持ってきて`.github/workflows/gh-pages.yaml`として保存してpushする。


## まとめ

* Octopress -> HugoはどっちもMarkdownを使うので移行はそんなに難しくない
* GitHub Actionsは楽
* こんなことより記事を書く方が重要なのでは？
