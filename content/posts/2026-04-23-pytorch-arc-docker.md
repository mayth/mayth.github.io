---
title: "PyTorch with Intel Arc in Docker"
date: 2026-04-23T23:50:00+09:00
draft: true
author: Mei Akizuru
slug: pytorch-arc-docker
tags:
    - tech
    - PyTorch
    - Intel Arc
    - Docker
---

## 背景

[Stable DiffusionをUbuntu 22.04, Radeon RX 6600 XTで動かす]({{% ref "2023-04-22-stable-diffusion-on-linux-with-radeon.md" %}})という記事がもう3年も前なんですが、今になってちょっとまともに今のサーバー機でもなんか動かすか……と思って色々弄ったので、その備忘録を残しておきます。

## 前提

サーバー機の詳しい構成は[新しいサーバーを組んだ]({{% ref "2025-03-21-build-new-server.md" %}})を見てもらうとして、ソフトウェア的にはmicrok8sで構築されたk8sクラスタが動いています。

今このクラスタではメディアサーバー（Jellyfin）が動いていて、こいつでハードウェアアクセラレーションを使うため、ホストにIntelのGPUドライバ、k8sクラスタには[Intel GPU device plugin for Kubernetes](https://intel.github.io/intel-device-plugins-for-kubernetes/cmd/gpu_plugin/README.html)を導入しています。`shared-dev-num`は2以上に設定して、複数のpodがGPUを使えるようにしてあります。この設定が1のままだと1つのpodがGPUを占有するので、GPUを利用したい他のpodがリソースを確保できず起動不能になります。

今回PyTorchのイメージを自前でビルドしていますが、これはIntel Extension for PyTorchが廃止されており、これが入ったDockerイメージのメンテナンスも止まっていることに起因します。[intel/intel-extension-for-pytorch](https://intel.github.io/intel-extension-for-pytorch/)が先月30日にアーカイブされていて、GitHubでアーカイブされてるという表記を見て初めて気付きました。これUbuntu 22.04ベースでだいぶ古かったので、どうしたものかなと思ってたんですが、[Welcome to Intel® Extension for PyTorch* Documentation!](https://intel.github.io/intel-extension-for-pytorch/)をよく見たらRetirement Planとか出てたんですよね……ドキュメントはちゃんと読もう。

それはそれとして、じゃあこれが退役したらその後どうするのという話については、IntelプラットフォームのサポートはPyTorch本家に取り込まれており、本家を使えということになっています。そのため、今回はPyTorchのxpu版を導入することにします。

## やること

### イメージを作る

先にDockerfileを示します。

```dockerfile
FROM ubuntu:24.04 AS xpu-base
ARG TARGETARCH

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends --fix-missing \
            python3.12 \
            python3.12-venv \
            python3-pip \
            python-is-python3 \
            curl \
            git \
            gnupg2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sL https://repositories.intel.com/gpu/intel-graphics.key | \
    gpg --yes --dearmor -o /usr/share/keyrings/intel-graphics.gpg

RUN echo "deb [arch=${TARGETARCH} signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu noble unified" | \
    tee /etc/apt/sources.list.d/intel-gpu-noble.list

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends --fix-missing \
            intel-opencl-icd \
            intel-ocloc \
            libze1 \
            libze-dev \
            xpu-smi && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir --break-system-packages \
        --index-url https://download.pytorch.org/whl/xpu \
        torch torchvision torchaudio
```

大雑把には3段階で、

1. 基本的なパッケージとPython 3の導入
2. Intelのパッケージリポジトリを追加してIntelのドライバ類をインストール
3. xpu版PyTorchをインストール

という流れです。rootで`pip install`すると怒られて止まるので気軽に`--break-system-packages`をつけてますが、果たしてこれで正しいのかは分かりません。まぁ、そうは言ってもUbuntu公式に最新のxpu版PyTorchなんて置いてあるわけがないので、残る選択肢は非rootユーザーになることだけな気がします。その場合、ドライバ類のインストールまでは同じで、PyTorchを入れる前に一般ユーザーの作成とそのユーザーへの切替をすれば大丈夫だと思います。こんな感じで:

```dockerfile
RUN groupadd --gid $GROUPID $GROUPNAME && \
    useradd -m -s /bin/bash -u $USERID -g $GROUPID $USERNAME
USER $USERNAME
WORKDIR /home/$USERNAME
# ...
```

あと`python-is-python3`は本当に人をナメてるとしか思えませんが、これがないと壊れることがままあるので入れておきました。

イメージビルド時には特に気にすることはありませんが、実行時に気を付けることがあります。

1. `docker run`の起動オプションに`--device /dev/dri`をつける
2. `docker run`の起動オプションで`--group-add`を使って、コンテナ内の実行ユーザーを`render`グループに所属させる or rootで実行する

まずひとつ目はホストからコンテナにGPUを見せるために必須です。2番目の方ですが、1番目の設定で`/dev/dri/*`がコンテナ内から見えるようになり、このデバイスファイルを通して色々できるのですが、デフォルトだとothersからアクセスできません。

```bash
$ ls -l /dev/dri
total 0
drwxr-xr-x  2 root root         80  4月  5 17:46 by-path
crw-rw----+ 1 root video  226,   1  4月 16 03:26 card1
crw-rw----+ 1 root render 226, 128  4月 16 03:26 renderD128
```

この`/dev/dri/renderD128`が触れないといけないので、コンテナ内の実行ユーザーはrootであるか`render`グループに属している必要があります。何もしなければ実行ユーザーはrootなのでこれらのファイルに触れますが、上述のようにコンテナ内の実行ユーザーをnon-rootユーザーに切り替えている場合、実行ユーザーが`render`グループに所属してないといけません。そこで`docker run`する際に`--group-add`を指定することで、実行ユーザーを特定のグループに所属させます。

ちなみにこの`--group-add`はGIDではなくグループ名で指定しても良いそうですが、コンテナ内に存在しない名前を指定するとエラーになります。ホスト側で`getent`とかを使ってGID取得するのが丸い気がします。

### Kubernetesから使う

今回Docker Hubへのpublish前に試そうと思ったんですが、microk8sで動いているクラスタにおいてローカルでビルドしたイメージを使うには一手間必要です。microk8sのドキュメント（[How to use a local registry](https://canonical.com/microk8s/docs/registry-images)）に記載がありますが、抜粋するとこうです。

```bash
docker save mynginx > myimage.tar
microk8s ctr image import myimage.tar
```

つまり一旦イメージをファイルに書き出してから取り込むことになります。PyTorchが入る関係上かなり巨大なイメージになっており、書き出すのも取り込むのも時間がかかるので注意が必要です。なお、当然ながら、この工程はDocker Hub等にアップロードされている場合は飛ばして大丈夫です。

で、k8sの定義ですが、Deploymentの重要部分だけ抜粋して示します。

```yaml
spec:
  template:
    spec:
      securityContext:
        supplementalGroups:
          # "render" group on host system
          - 992
      containers:
      - name: pytorch
        resources:
          requests:
            gpu.intel.com/xe: 1
          limits:
            gpu.intel.com/xe: 1
```

`.spec.template.spec.securityContext.supplementalGroups`でホストの`render`グループのGIDを指定します。これは先述の`docker run`で動かす場合には`--group-add`で`render`に所属させないといけないというのと同じ話です。なお、`/dev/dri`云々の話はDevice Pluginが面倒を見てくれるので気にしなくて大丈夫です。

もうひとつは`.spec.template.spec.containers[].resources.{requests,limits}.gpu.intel.com/xe`で、この記述によってGPUを要求します。
ちなみに`gpu.intel.com/`の後ろの文字列は使うドライバーによって変わります。B580（Battlemage世代）ではxeドライバー以外に選択肢はありませんが、もう少し古い世代の統合グラフィックスの場合は`i915`を使う可能性もあります。このあたりは使うGPUに応じてよしなにしましょう。

## まとめ

というわけでPyTorchイメージの作り方とその使い方でした。

どうしてもIntel Arc自体がマイナー（というかGeForceが強すぎる）なのもあって全然情報がないのと、ちょうどIntel Extension for PyTorchが死んだところというタイミングが神懸かってしまい遠回りした感があります。みなさんもIntel CPU + Intel GPU（+おまけでSolidigm SSD）の最強ブルーチームで最高のコンピューティング環境を実現しましょう。
