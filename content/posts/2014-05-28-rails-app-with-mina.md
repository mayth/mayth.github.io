---
title: "Railsアプリ with Mina and OpenRC"
date: 2014-05-28 00:07:56 +0900
author: Mei Akizuru
slug: rails-app-with-mina
tags:
    - Rails
aliases:
    - /blog/2014/05/28/rails-app-with-mina/
---

# 目的とか

KONMAIが送る大人気リズムアクションゲーム"REFLEC BEAT groovin'!!"に向けてRefixativeの新バージョンを書いていた。今までは毎回毎回サーバーにsshしてはgit pullしてうんぬんかんぬん、とやっていたので、現代的な環境を構築したかった。

ついでに、サーバーを再起動する度にunicornのプロセス周りがなぜだかややこしいことになっていたので、どうせそもそもデーモンなんだからinitスクリプトを書けばいいんじゃね、ということでそっちもついでに対応した。

OpenRCの実装を読み始めた辺りから変な沼にハマって、そこから3日くらいかかった。

# 環境その他

開発環境はMac OS X Mavericks。Homebrewでいろんなものを突っ込んである状態。

サーバーはさくらのVPS(2G)でOSとしてGentoo Linuxがインストールされている。

Rubyのバージョンは2.1.2、Railsのバージョンは4.1.1。

DBにPostgreSQL 9.3を使用。現時点ではまだ用意していないが、memcachedも使用する予定。

# Rails

`rails new`して適当にGemfileを弄って`bundle install --path vendor/bundle`。

## rbenv on Gentoo

まず第一関門がRubyだった。Gentoo上でrbenvやRVMを使ってRubyをインストールすると、`auto_gem`なるライブラリがないと言われてRubyが動かないという問題に遭遇した。ググってみると同じ問題に遭遇している人が多数いた。`RUBYOPT`を空にして`rubygems`をemergeしなおせばいいよ、とかまぁいろいろ見つかったのだけど、そもそも`auto_gem`というのが気になり、Twitterでいろいろ叫びながら調べていたところ、Gentooのこわいひとに教えてもらうことができた。

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr"><a href="https://twitter.com/maytheplic?ref_src=twsrc%5Etfw">@maytheplic</a> いまgentoo ruby teamとIRCしたらruby18はもうおとつつあるしけしていいね、って話になったし3日ぐらいしたらそのあたりもきえちゃうんじゃないかな</p>&mdash; 漢字変換の権を他人に握らせない🙅 (@naota344) <a href="https://twitter.com/naota344/status/469523144915427330?ref_src=twsrc%5Etfw">May 22, 2014</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

（ちなみにその後Gentooのこわいひとが次のように仰っていたので、きっとこの問題は起こらなくなるだろう）

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr"><a href="https://twitter.com/maytheplic?ref_src=twsrc%5Etfw">@maytheplic</a> いまgentoo ruby teamとIRCしたらruby18はもうおとつつあるしけしていいね、って話になったし3日ぐらいしたらそのあたりもきえちゃうんじゃないかな</p>&mdash; 漢字変換の権を他人に握らせない🙅 (@naota344) <a href="https://twitter.com/naota344/status/469523144915427330?ref_src=twsrc%5Etfw">May 22, 2014</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

さて、それはともかくとして、少なくともこれをやってた時点では直ってなかったので対策をしなければならない。

そもそも`auto_gem.rb`とやらが何をしているのかというと、

* `require 'rubygems'`する
* そのときに`LoadError`が起きたら握り潰す

以上である。Gentooのこわいひとの言う通り、見事に現代には不要なブツである。不要なのだから、現代的なRuby環境では「何もしなくてもよい」ということができる。というわけで、適当に`site_ruby`辺りに空の`auto_gem.rb`を突っ込んでしまえばよい。例えばRuby 2.1.2であれば、

```
touch $HOME/.rbenv/versions/2.1.2/lib/ruby/site_ruby/2.1.0/auto_gem.rb
```

とかやると動くようになる。

ちなみにruby-buildを使っている場合はインストール後にそれを自動でやってくれるpluginがある。 -> [Cofyc/rbenv-auto_gem](https://github.com/Cofyc/rbenv-auto_gem)

これを`$HOME/.rbenv/plugins`の下にcloneして`rbenv install ...`とかやると適切な場所に空の`auto_gem.rb`を作ってくれる。

これでRubyが動くようになった。

## therubyracer

`rake assets:precompile`をしたとき、ローカルでは上手くいくのに、サーバー側ではSegmentation FaultでRubyが落ちるという事態に遭遇した。吐かれたエラーを見るとtherubyracerがどうの、といったところで落ちていた。サーバー側にはnode.jsが入っているし、特に問題ないだろうと判断してGemfileからtherubyracerを消したところ上手く動作した。なんだったんだろう。

# Mina

[Mina](http://nadarei.co/mina/)はデプロイ自動化ツールで、同じようなツールで最も有名なのは恐らく[Capistrano](http://capistranorb.com)だろう。

今までRefixativeのデプロイというのはHerokuのように`git push`したら行われるとかなんかのbotにコマンド投げると行われるとかでは全くなく、開発者自身（つまり私）がデプロイ先サーバーにsshして、アプリケーションが置いてあるフォルダに移動して、git pullして、unicornをreloadして……とやっていた。正直アホらしい。

そういうわけでその辺自動化するためにCapistranoでも触るか……と思っていたところで某筑波のておくれからこんなreplyが来た。

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr"><a href="https://twitter.com/maytheplic">@maytheplic</a> minaがナウいらしい <a href="http://t.co/MDwGLIx7Y0">http://t.co/MDwGLIx7Y0</a></p>&mdash; まてぃー (@rkmathi) <a href="https://twitter.com/rkmathi/status/459561993729347587">2014, 4月 25</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

ナウいらしい。ならば使うしかあるまい。というわけでMina採用となった。

## その前に

サーバー側でRailsアプリを動かすユーザー等々を準備しておく。

まずユーザー（今回は`refxgroovin`）を予め作成しておく。デプロイ先はこのユーザーのホームディレクトリ以下とし、今回は`/home/refxgroovin/refixative`としている。ステージング環境も同じユーザーで動かし、そちらのデプロイ先は`refixative-staging`とした。

開発環境からサーバーに対してrefxgroovinとしてsshでログインできるように設定する。開発環境で公開鍵・秘密鍵のペアを作成し、サーバー側の`/home/refxgroovin/.ssh/authorized_keys`に公開鍵を追記する。

ソースコードを取得する元になるリポジトリだが、今回github上にあるpublicなリポジトリなので実際どっちでもよさそうだし、SSH Agentを使うこともできるが、今回はさらにサーバー上のrefxgroovinユーザーでSSHの鍵を生成してリポジトリにアクセスできるように設定する。

## Minaの準備

まずはGemfileに`gem 'mina'`の一行を追加して`bundle`した後、

```bash
$ bundle exec mina init
```

とすると、`config/deploy.rb`というファイルが出来るのでこれを編集する。以下に示す`deploy.rb`はデフォルトを元にいろいろ試行錯誤した結果である。

```ruby
require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
require 'mina/rbenv'  # for rbenv support. (http://rbenv.org)
# require 'mina/rvm'    # for rvm support. (http://rvm.io)

# Optional settings:
#   set :user, 'foobar'    # Username in the server to SSH to.
#   set :port, '30000'     # SSH port number.

set :user, 'refxgroovin'

# Basic settings:
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)

set :domain, 'refxgroovin'
set :repository, 'git@github.com:mayth/refixative.git'
set :branch, 'next'

# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, [
  'config/database.yml',
  'config/unicorn.rb',
  'config/application.yml',
  'log'
]

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  case ENV['to']
  when 'staging'
    set :deploy_to, "/home/#{user}/refixative-staging"
  when 'production'
    set :deploy_to, "/home/#{user}/refixative"
  when nil
    fail 'specify `to`, deployment target'
  else
    fail 'unknown deployment target'
  end

  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .rbenv-version to your repository.
  invoke :'rbenv:load'
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task :setup => :environment do
  queue! %[mkdir -p "#{deploy_to}/shared/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/log"]

  queue! %[mkdir -p "#{deploy_to}/shared/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/config"]

  queue! %[mkdir -p "#{deploy_to}/shared/pids"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/pids"]

  shared_configs = %w(database.yml unicorn.rb application.yml)
  shared_configs.each do |conf|
    queue! %[touch "#{deploy_to}/shared/config/#{conf}"]
  end
  queue  %[echo "-----> Be sure to edit the following files in 'shared/config':"]
  shared_configs.each do |conf|
    queue  %[echo "----->   * #{conf}"]
  end
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'

    to :launch do
      env = ENV['to'] == 'production' ? '' : ".#{ENV['to']}"
      cmd = ENV['reload'] || 'reload'
      queue %[sudo /etc/init.d/refxgroovin#{env} #{cmd}]
    end
  end
end

# For help in making your deploy script, see the Mina documentation:
#
#  - http://nadarei.co/mina
#  - http://nadarei.co/mina/tasks
#  - http://nadarei.co/mina/settings
#  - http://nadarei.co/mina/helpers
```


### shared_paths

`shared_paths`に指定されたファイル・ディレクトリは、デプロイしたときに"#{deploy_to}/shared"にシンボリックリンクが張られるようになる。例えば`config/database.yml`を指定すると、デプロイしたときに`/home/refxgroovin/current/config/database.yml`から`/home/refxgroovin/shared/config/database.yml`にリンクが張られる。これによってサーバーに依存するファイルをいちいち書き換える必要がなくなる（んだろう、たぶん）。

（※Minaはデプロイした最新版を"#{deploy_to}/current"とする。これもシンボリックリンクで、実体は`releases`フォルダ以下にある）

例えばRails 4.1の`config/secrets.yml`。これは`rails new`したときに生成される`.gitignore`に含まれていてリポジトリにはないはずである。ここで、`shared_paths`に`config/secrets.yml`を設定して実体を`shared/config/secrets.yml`に置いておけば、デプロイ時にシンボリックリンクが作成されるので捗る、と思う。（ちなみにRefixativeの場合は[Figaro](https://github.com/laserlemon/figaro)で管理しているので`config/secrets.yml`はリポジトリに存在している。その内容は単に環境変数を見るだけのものである。この場合は代わりに`config/application.yml`が存在しないので、これを`shared_paths`に設定してある）

注意点としては、あくまで自動でリンクを張るだけであって実体に関しては何も関知しないので、それは自分で作成する必要がある。

### セットアップ

その辺りの設定ができたら開発環境でセットアップのコマンドを発行する。

```bash
$ bundle exec mina setup to=production
```

`to=production`に関しては、今回はproduction/stagingを切り替えられるようにしたので必須である（デフォルトのままなら必要ない）。これでデプロイ先にはMinaのディレクトリ構造が生成され、sharedディレクトリ以下にいくつかファイルやディレクトリが生成される。

メッセージにあるとおり、`shared`以下のファイルは自分で編集しなければならないので、サーバー側で編集する。

### デプロイ

ここまで終われば、開発環境に戻ってきて

```bash
$ bundle exec mina deploy to=production
```

とする。このコマンドによってsshしてgit cloneして云々……が実行され、最後に`to :launch`で書いた内容が実行され、デプロイは終了する。上述の例だとここで独自のinitスクリプトを用いているのでそれを用意しておく必要があるが、デフォルトだと`restart.txt`をtouchして終わりなので、特に何も起きずに終了するはずである。

# サーバー側環境構築

rbenvとかrubyのインストールは省略。そこでハマったのは前述の点くらいである。

## initスクリプトを書こう

Gentoo Linuxでは標準でOpenRCというinitシステムを採用している。それを踏まえた上で、unicornのデーモンを管理するためのinitスクリプトを書く。書き方は[Gentoo Linux Documentation -- Initscripts](http://www.gentoo.org/doc/en/handbook/handbook-x86.xml?part=2&chap=4)辺りを見たり、他のinitスクリプトを参考にする。今回は特にapache2とpostgresql-9.3を参考にして書いてみた。

```sh
#!/sbin/runscript
# Distributed under the terms of the MIT License
# $Header: $

extra_started_commands="reload"

description_graceful="Reexecutes the running binary and stops the old master after the old workers finish their current request."
description_gracefulstop="Stops the server after the workers finish their current request."
description_reload="Reexecutes the running binary and stops the old master immediately."

CONF="${RC_SVCNAME#*.}"

[ "${CONF}" == "refxgroovin" ] && CONF='production'

if [ "${CONF}" == "production" ]; then
	REFXGROOVIN_BASE="/home/refxgroovin/refixative"
else
	REFXGROOVIN_BASE="/home/refxgroovin/refixative-${CONF}"
fi
PIDFILE="${REFXGROOVIN_BASE}/shared/pids/unicorn.pid"

RBENV_DIR="/home/${REFXGROOVIN_USER}/.rbenv"
PATH="${RBENV_DIR}/bin:$PATH"

depend() {
	need net postgresql
}

start() {
	ebegin "Starting Refixative groovin'!! ${CONF} server"
	start-stop-daemon --start \
		--name unicorn_rails \
		--chdir ${REFXGROOVIN_BASE}/current \
		--user ${REFXGROOVIN_USER} \
		--pidfile ${PIDFILE} \
		--exec rbenv -- exec bundle exec unicorn_rails -c "${REFXGROOVIN_BASE}/current/config/unicorn.rb" -E production -D
	eend $?
}

stop() {
	local seconds=$(( ${GRACEFUL_TIMEOUT} + ${FORCE_TIMEOUT} ))
	ebegin "Stopping Refixative groovin'!! ${CONF} server gracefully (this can take up to ${seconds} seconds)"
	local retries="SIGQUIT/${GRACEFUL_TIMEOUT}"

	if [ "${FORCE_QUIT}" = "YES" ] ; then
		einfo "FORCE_QUIT enabled."
		retries="${retries}/SIGTERM/${FORCE_TIMEOUT}"
	fi

	start-stop-daemon --stop \
		--pidfile ${PIDFILE} \
		--retry "${retries}"
	eend $?
}

restart() {
	stop

	local timeout=${RESTART_TIMEOUT:-10}
	local i=0 retval=0
	while [ -e ${PIDFILE} ] && [ $i -lt ${timeout} ] ; do
		sleep 1 && i=$(expr $i + 1)
	done
	[ -e ${PIDFILE} ] && retval=1
	eend ${retval} "Unable to confirm whether the server stopped or not."
	[ ${retval} -ne 0 ] && return ${retval}

	sleep 2 # waiting a little for COMPLETELY stopped the old master

	start
}

reload() {
	local retval=0

	ebegin "Reloading Refixative groovin'!! ${CONF} server"
	kill -USR2 `cat ${PIDFILE}`
	retval=$?
	eend ${retval} "Unable to reload the server."
	[ ${retval} -ne 0 ] && return ${retval}

	local timeout=${RELOAD_TIMEOUT:-10}
	local oldbin="${PIDFILE}.oldbin"
	ebegin "Waiting for restarting (this can take up to ${timeout} seconds)"
	local i=0
	retval=0
	while [ ! -e ${oldbin} ] && [ $i -lt ${timeout} ] ; do
		sleep 1 && i=$(expr $i + 1)
	done
	[ ! -e ${oldbin} ] && retval=1
	eend ${retval} "Unable to found the old pidfile at ${oldbin}"
	[ ${retval} -ne 0 ] && return ${retval}

	ebegin "Stopping old Refixative groovin'!! ${CONF} server"
	kill -QUIT `cat ${oldbin}`
	eend $?
}

# vim: ts=4 filetype=gentoo-init-d
```

`reload`はUSR2+QUITの組み合わせでダウンタイムなしでの更新を行うものである。あと`restart`はタイミングの問題か何かで、前のmasterがリッスンしているポートを手放す前に新しいmasterが動き始めて起動に失敗することがあったので、とりあえず間に`sleep 2`を入れてある。ひとまずこれで安定して再起動できる。適当。

最初は強制的なstop（TERMシグナル）とgracefulなstop（QUITシグナル）を別のコマンドに分けていたのだが、`stop()`のときに呼ばれる処理が`gracefulstop()`とかにしてしまうと呼ばれないために、gracefulstopしてもサービスが停止していないと判断されてしまった。そんなわけで、postgresqlのスクリプトを参考にしてstopを書き換えた。`start-stop-daemon`は`--retry`オプションに所定の形式のリストを渡すと、最初の要素から順に指定されたタイムアウト分だけ待ちながらシグナルを送ってくれる。これを用いて、最初はQUITを送り、それから一定時間経っても終了出来なければTERMを送るような処理になっている。

こんな感じのスクリプトを`/etc/init.d/refxgroovin`として作成して、あといくつか変数を定義したファイルを`/etc/conf.d/refxgroovin`として作成する。conf.dの方では`REFXGROOVIN_USER`の設定が必須である。これ以外にいくつかのタイムアウトの設定を行う。そうしたら

```bash
$ /etc/init.d/refxgroovin start
```

としてサービスを起動させる。これでログを確認してmasterがreadyになっていて、かつ`curl`か何かでリクエストを投げて返事が返ってくれば成功である。

### stagingの話

ところで今回はstaging環境にも対応させている。initスクリプトは`refxgroovin.(env)`という名前で`refxgroovin`へのシンボリックリンクを張ればおしまいである。つまり、`refxgroovin.staging`という名前でシンボリックリンクを作成すると、それがstaging環境向けのinitスクリプトになる。

conf.dの方はシンボリックリンクではなくコピーで対応する。

## sudoers

デプロイが完了したとき、refxgroovinユーザーでサービスの再起動またはreloadが出来ればよい。しかしながらサービスの操作というのは当然スーパーユーザーでないとできない。そこでsudoである。でもrefxgroovinユーザーはunicornを動かすので、仮にunicornやRails、アプリケーション自身に任意コマンド実行の脆弱性があった場合、sudoから何かされる可能性がある。だからといってrefxgroovinユーザーにパスワードを設定するとデプロイする度にパスワードを入力しなきゃいけなくて、それは面倒（ここは運用方針に依存する気がするけど）。

そういうわけで、refxgroovinユーザーに対しては「任意のユーザーとして、パスワードなしで、/etc/init.d/refxgroovinと/etc/init.d/refxgroovin.stagingの実行のみを許可する」ように設定する。

```
refxgroovin ALL = (ALL) NOPASSWD: /etc/init.d/refxgroovin, (ALL) NOPASSWD: /etc/init.d/refxgroovin.staging
```

を`visudo`で追記する。`(ALL) NOPASSWD:`は2回書かなくてよかったような気もするのだが、何か動かなかったので2回書いてある（他に原因があったかもしれない）。

この状態で一度試しにサーバー上で

```bash
$ sudo /etc/init.d/refxgroovin reload
```

とかやって動くかどうかを確認する。動かなかったらググってみるとかmanを読むとかしてほしい。

ひとまずこれでrefxgroovinユーザーがroot（とか他のユーザー権限）で出来ることはinitスクリプトを使ってrefxgroovinデーモンを操作することだけになった、はずである。たぶん。

ちゃんと動いたならば、`deploy.rb`の`to :launch`を書き換える。上記の例のように`queue`を使って`sudo`を呼べばよい。編集したらデプロイしてみて、ちゃんとデプロイが成功するかどうかを確認する。

私は当初unicornのpidfileをデフォルトの位置に設定していたが、この設定ではreloadが失敗した。

pidfileのデフォルトの位置は`#{APPROOT}/tmp/pids/unicorn.rb`だが（今回であれば`APPROOT`は`/home/refxgroovin/current`）、Minaがlaunchを試みるのは*currentが最新版のコードベースに置き換わった後*である。つまり、例えば元々`releases/4`がcurrentだったとして、その状態でデプロイして`to :launch`が動くのはcurrentが`releases/5`に置き換わった後になる。要はpidfileはreleases/4/tmp/pidsにあるのに、releases/5/tmp/pidsを見に行ってしまう。当然そこには何もないのでpidfileがないといって失敗する。

そんなわけで明示的に、かつデプロイ時にシンボリックリンクとかで実体の位置が変わらない場所にpidfileの場所を設定しておく必要がある。今回の場合は`shared/pids/unicorn.pid`にした。shared以下に配置しているが、`shared_paths`には設定していない（こういう使い方がMina的にOKなのかは知らない）。またディレクトリ自体がないと起動に失敗するので、setup時に`shared/pids`ディレクトリを作成するようにした。