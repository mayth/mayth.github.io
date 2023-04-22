---
title: "Stable DiffusionをUbuntu 22.04, Radeon RX 6600 XTで動かす"
date: 2023-04-22T13:01:50+09:00
author: Mei Akizuru
slug: stable-diffusion-on-lilnux-with-radeon
tags:
    - tech
    - Ubuntu
    - Radeon
    - Stable Diffusion
---

## 背景

ミドルレンジとはいえせっかくディスクリートのGPU積んでるのに何もしてない（ゲームはしてる）のはもったいない、ということでひとつ試しにStable Diffusionを動かしてみることにした。

## 環境

|     |     |
| --- | --- |
| **CPU** | Intel Core i5-12600KF (6+4C/16T) |
| **メモリ** | crucial DDR4-3200 32GB (16GBx2) |
| **GPU** | Radeon RX 6600 XT (ASRock AMD Radeon RX 6600 XT Challenger D 8GB OC) |
| **SSD** | WD My Passport 1TB |

ソフトウェア類は以下の通り。

|   |   |
| - | - |
| **OS** | Kubuntu 22.04 LTS (Kernel 5.19.0-40-generic) |
| **ドライバー** | Radeon Software for Linux version 22.40.3 |
| **ROCm** | 5.4.2 |

普段はゲーム機専用OSであるところのWindowsが稼働しているマシンだが、外付けのSSDにKubuntu 22.04 LTSをインストールして使用する（元々持ち運べるLinux開発環境として使っていた）。記事のタイトルはUbuntuだけどまぁ公式のフレーバーなので許してほしい。

なおLinuxを選んだ理由は現時点でROCmがWindowsをサポートしていないからである。

## 作業手順

### GPUドライバーのインストール

まずRadeon Software for Linuxをインストールする。[公式のドキュメント](https://amdgpu-install.readthedocs.io/en/latest/)に従って作業する。

[Linux Drivers for AMD Radeon and Radeon PRO Graphics](https://www.amd.com/en/support/linux-drivers)からインストーラーを導入する。Ubuntu x86 64-Bitの下にあるRadeon Software for Linux version 22.40.3 for Ubuntu 22.04.2をダウンロードし、落としてきたdebパッケージをインストールする。

```
$ sudo apt install ~/Downloads/amdgpu-install_5.4.50403-1_all.deb
$ sudo apt update
```

OpenCLを使う場合には`render`および`video`グループに属している必要がある。実際に必要かわからないが後で引っかかると嫌なので追加しておく。

```
$ sudo usermod -a -G render $LOGNAME
$ sudo usermod -a -G video $LOGNAME
```

実際にドライバーをインストールする。usecaseにrocmを与える（逆にgraphicsはいらないかも）。なお、ドライバーのインストール中にSecure Bootの関係でインストールの確認と、確認用パスワードの設定を求められる。これは後で一度だけ必要になる。

```
$ sudo amdgpu-install --usecase=graphics,rocm
...
$ sudo reboot
```

再起動後にMOKマネージャが起動するので、Enroll MOKを選んで登録する。ここで先程のパスワードを入力して登録を完了させ再起動する。起動してきたら`rocminfo`を実行してみる。

```
$ sudo rocminfo
ROCk module is loaded
=====================    
HSA System Attributes    
=====================    
Runtime Version:         1.1
System Timestamp Freq.:  1000.000000MHz
Sig. Max Wait Duration:  18446744073709551615 (0xFFFFFFFFFFFFFFFF) (timestamp count)
Machine Model:           LARGE                              
System Endianness:       LITTLE                             
...
*******                  
Agent 2                  
*******                  
  Name:                    gfx1032                            
  Uuid:                    GPU-XX                             
  Marketing Name:          AMD Radeon RX 6600 XT              
  Vendor Name:             AMD                                
  Feature:                 KERNEL_DISPATCH                    
  Profile:                 BASE_PROFILE                       
  Float Round Mode:        NEAR                               
  Max Queue Number:        128(0x80)                          
  Queue Min Size:          64(0x40)                           
  Queue Max Size:          131072(0x20000)                    
  Queue Type:              MULTI                              
  Node:                    1                                  
  Device Type:             GPU
```

Agent 2としてRX 6600 XTが見えていることが確認できた。

### Stable Diffusion Web UIのセットアップ

今回は[AUTOMATIC1111/stable-diffusion-webui](https://github.com/AUTOMATIC1111/stable-diffusion-webui)を使用した。これを書いている時点での最新のコミットは2023-03-29の[22bcc7b](https://github.com/AUTOMATIC1111/stable-diffusion-webui/tree/22bcc7be428c94e9408f589966c2040187245d81)。
作業手順としてはこのリポジトリのWikiに[Install and Run on AMD GPUs](https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Install-and-Run-on-AMD-GPUs)というページがあるのでこれに従う。

Pythonのバージョンを確認しておく。ドキュメントでは3.10.6を使っているので、必要であれば更新する。今回は最初から同じバージョンなのでこのまま進める。venvが必要になるので、入ってなければ入れておく。また、pipとwheelについてもインストール・更新を行う。

```
$ python -V
Python 3.10.6
$ python -m venv venv
$ sudo apt install python3.10-venv
$ python -m pip install --upgrade pip wheel
```

リポジトリをcloneする。

```
$ git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui
$ cd stable-diffusion-webui
```

`models/Stable-diffusion`ディレクトリにチェックポイントファイルをコピーする。今回は[OrangeMixs](https://huggingface.co/WarriorMama777/OrangeMixs)からAbyssOrangeMix3を使用した。

公式の手順にある`COMMANDLINE_ARGS`に`--precision full --no-half`を加える部分は、注釈にもあるがRX 6000シリーズなのでスキップした。実際この点では問題が起きなかった。

このまま素直に`webui.sh`を起動するとこんな具合でCUDAにアクセスできないといって失敗する。

```
################################################################
Launching launch.py...
################################################################
Python 3.10.6 (main, Mar 10 2023, 10:55:28) [GCC 11.3.0]
Commit hash: 22bcc7be428c94e9408f589966c2040187245d81
Traceback (most recent call last):
  File "/home/mayth/devel/src/github.com/AUTOMATIC1111/stable-diffusion-webui/launch.py", line 355, in <module>
    prepare_environment()
  File "/home/mayth/devel/src/github.com/AUTOMATIC1111/stable-diffusion-webui/launch.py", line 260, in prepare_environment
    run_python("import torch; assert torch.cuda.is_available(), 'Torch is not able to use GPU; add --skip-torch-cuda-test to COMMANDLINE_ARGS variable to disable this check'")
  File "/home/mayth/devel/src/github.com/AUTOMATIC1111/stable-diffusion-webui/launch.py", line 121, in run_python
    return run(f'"{python}" -c "{code}"', desc, errdesc)
  File "/home/mayth/devel/src/github.com/AUTOMATIC1111/stable-diffusion-webui/launch.py", line 97, in run
    raise RuntimeError(message)
RuntimeError: Error running command.
Command: "/home/mayth/devel/src/github.com/AUTOMATIC1111/stable-diffusion-webui/venv/bin/python3" -c "import torch; assert torch.cuda.is_available(), 'Torch is not able to use GPU; add --skip-torch-cuda-test to COMMANDLINE_ARGS variable to disable this check'"
Error code: 1
stdout: <empty>
stderr: Traceback (most recent call last):
  File "<string>", line 1, in <module>
AssertionError: Torch is not able to use GPU; add --skip-torch-cuda-test to COMMANDLINE_ARGS variable to disable this check
```

同様のエラーで詰まっている報告はいくつも見られたが、解決策は特に見当たらなかった。ちなみにエラーメッセージにあるように、`webui-user.sh`を編集して`COMMANDLINE_ARGS`に`--skip-torch-cuda-test`（と`--no-half`）を追加すれば起動はするが、GPUを使用せずCPUだけで生成するため、512x512 20stepで2分かかる。

`webui.sh`を見ていくと、[L106-L122](https://github.com/AUTOMATIC1111/stable-diffusion-webui/blob/22bcc7be428c94e9408f589966c2040187245d81/webui.sh#L106-L122)でAMD GPU向けの処理をしているのだが、最後のPytorchを入れるコマンドを`pip install torch torchvision --extra-index-url https://download.pytorch.org/whl/rocm5.2`としており、ROCm 5.2に決め打ちしている。マシンに入っているのはROCm 5.4.2なので、ここが食い違って動いていないのだと判断して、[`webui-user.sh`の28行目](https://github.com/AUTOMATIC1111/stable-diffusion-webui/blob/22bcc7be428c94e9408f589966c2040187245d81/webui-user.sh#L28)を編集してROCm 5.4.2に対応するバージョンをインストールするようにした。実際に必要なコマンドは[PytorchのStart Locally](https://pytorch.org/get-started/locally/)のページで環境を選んで確認する。

```sh
export TORCH_COMMAND="pip install torch torchvision --extra-index-url https://download.pytorch.org/whl/rocm5.4.2"
```

依存関係の整理が面倒なので一旦virtualenvをすべて消して再セットアップしてもらう。

```
$ rm -rf venv
$ ./webui.sh
```

これで無事起動したが、次は画像生成時に以下のエラーを吐いてクラッシュする。

```
MIOpen(HIP): Error [Compile] 'hiprtcCompileProgram(prog.get(), c_options.size(), c_options.data())' naive_conv.cpp: HIPRTC_ERROR_COMPILATION (6)
MIOpen(HIP): Error [BuildHip] HIPRTC status = HIPRTC_ERROR_COMPILATION (6), source file: naive_conv.cpp
MIOpen(HIP): Warning [BuildHip] /tmp/comgr-256045/input/naive_conv.cpp:39:10: fatal error: 'limits' file not found
#include <limits> // std::numeric_limits
         ^~~~~~~~
1 error generated when compiling for gfx1030.
terminate called after throwing an instance of 'miopen::Exception'
  what():  /long_pathname_so_that_rpms_can_package_the_debug_info/data/driver/MLOpen/src/hipoc/hipoc_program.cpp:304: Code object build failed. Source: naive_conv.cpp
zsh: IOT instruction (core dumped)  ./webui.sh
```

これはパッケージの不足だったらしく、`libstdc++-12-dev`のインストールで解消された。

```
$ sudo apt install libstdc++-12-dev
```

改めてWeb UIを起動して、無事に画像を生成できた。起動後の初回生成だけ若干遅いが（数秒間0%のまま進まない）、きちんとGPUが有効になっていれば1枚あたり5秒前後で生成される。ログを見るとだいたい4.4it/s程度だった。

生成中のシステムモニターはこんな具合で、生成中はGPUが100%に張り付き、またCPUも1コアだけ100%に張り付くような挙動を示す。

{{< fluid_imgs "pure-u|/images/2023-04-22-stable-diffusion-system-monitor.png|System Monitor during generating image" >}}


## まとめ

RX 6600 XTというとFullHDをターゲットにしたミドルレンジのGPUではあるが、1枚5秒で生成できる。RTX3060(12GB)と比べれば若干安いのとゲーミング性能（レイトレしない場合）で上回っているので、普通に作業やゲームでPCを使いつつ、たまに画像生成触ってみたい（自分で学習回したりはまずしない）というケースでは十分選択肢に入ると思う。VRAMが8GBしかないRTX3060なんてものはない。

これはまとめというか雑感と愚痴だが、AMDにはRyzenでIntelを殴り飛ばしたのと同じようにNVIDIAとも殴り合ってほしい。しかし皆CUDA前提に話をしててRadeon(ROCm)だと試しに使ってみようかな程度でもいくらか手間が増えるのではちょっと……ねえ？　という感じがある。
そもそも現時点の最新のROCmではコンシューマー向けのGPUを正式にはサポートしていないという時点でやる気あるのかと疑いたくなる（[v5.4.3 Prerequisites](https://docs.amd.com/bundle/ROCm-Installation-Guide-v5.4.3/page/Prerequisites.html)のサポートリストを見るとInstinctやRadeon Proシリーズといったサーバー・ワークステーション向けしかない）。アルファ版ではRDNA 2世代のコンシューマー向けGPUがサポートされるらしい。すでにRDNA 3のRX 7000シリーズが販売されているのだが……。

というわけで、画像生成やLLMを目的にGPUを調達したい人はGeForce選びましょう。私ももしARMORED CORE VIがレイトレ対応でACの質感がすごいんですよとか言われたらGeForceに乗り換えます。おしまい。
