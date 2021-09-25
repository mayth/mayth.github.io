---
title: "DatabaseRewinder with Rails 4.2 & PostgreSQL"
date: 2015-03-12 18:49:02 +0900
author: Mei Akizuru
tags:
  - Ruby on Rails
  - PostgreSQL
aliases:
    - /blog/2015/03/12/database-rewinder-with-rails-4-2/
---

Rails 4.2で新規プロジェクトを作ってPostgreSQLを使ったときにDatabaseRewinderが使えなかった話。私が使っていたのがDatabaseRewinderだったという話でたぶんDatabaseCleanerでも同じ現象は起こると思う。というか`disable_referential_integrity`を使っている限り起こると思う。

あとRails 4.2で外部キー制約をサポートしたから今ハマっただけで、実際のところ自分で外部キー制約を付与するとかしてたら同じ問題が起きていたはずで、ハマりやすくなった、というだけだとも思う。

# 原因

* Rails 4.2からmigrationにおいて外部キー制約をサポートした(ref: [Ruby on Rails 4.2 Release Notes](http://guides.rubyonrails.org/4_2_release_notes.html#foreign-key-support))。scaffoldとかで`references`や`belongs_to`を使うと、生成されるmigrationファイルには`add_foreign_key`が使われる。

* PostgreSQLでは外部キー制約はシステムトリガーでチェックされている。

* システムトリガーはスーパーユーザーでないと無効に出来ない。そのデータベースやテーブルのオーナーでも不可。

* DatabaseRewinderは`disable_referential_integrity`を使ってトリガーを無効にするが、上述の理由によりスーパーユーザーでないと無理。

* トリガーを無効にしようとした時点で例外が出て、トランザクションはロールバック、同一トランザクションの後続クエリは無視される。

* 例外が出てるのでテストは失敗する。

ちなみにここでいう「スーパーユーザー」はPostgreSQLのroleの話であって、システムのスーパーユーザーとは関係ない。

# 解決策

* スーパーユーザーでテストを走らせる。テストを動かすユーザーをスーパーユーザー権限を持ったユーザーに変更するか、テスト用のユーザーにスーパーユーザー権限を付与する:

```
ALTER ROLE username WITH SUPERUSER;
```

当たり前だがスーパーユーザー権限の付与にはスーパーユーザー権限が必要。

* （一時的に）外部キー制約を外す。

* PostgreSQL使うのやめる（他のデータベースでどうなるのかは調べてない）。

# ダメだった方法

* migrationの`add_foreign_key`で`on_delete`オプションを`cascade`か`nullify`にしてみる。

`on_delete: :cascade`にしてみたがダメだった。解決しない理由は、「スーパーユーザーでないのにトリガーを無効にしようとした」後に来るDELETE文の発行までそもそも辿り着いてないからだと思う。

つまるところ、外部キー制約に違反するかどうかは問題ではないという感じがある。

(2015-03-13 追記)

## ダメじゃなくなるかもしれない方法

`ActiveRecord::ConnectionAdapters::PostgreSQL::ReferentialIntegrity#supports_disable_referential_integrity?`が`false`を返すようにすれば、そもそも問題の`disable_referential_integrity`が呼ばれない。このとき、上記のように`on_delete: :cascade`(or `:nullify`)を指定して、外部キー制約に違反したときにDELETEが失敗しないようになっていれば、特に問題なく動作を続行できるはず。

※試してない。

# Links

* [Postgres system triggers error: permission denied | End Point Blog](http://blog.endpoint.com/2012/10/postgres-system-triggers-error.html)

この記事に「制約外せるのにその制約をチェックするトリガーを無効に出来ないのっておかしな話だよな」みたいなコメントがあって、確かになぁという気分になった。
