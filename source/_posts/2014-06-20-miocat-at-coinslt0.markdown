---
layout: post
title: "miocatのその後、あるいはcoinsLT #0で発表した話"
date: 2014-06-20 11:09:26 +0900
comments: true
categories: coinsLT miocat tkbctf3 CTF Mono .NET
---

情報科学類1年が企画した[coinsLT #0](http://atnd.org/events/51236)（ATNDの方が情報量が多いのだが、一応[Webページ](http://coinslt.org/zero.html)も存在している）で発表した。タイトルがクソ長いが要するにこのブログでいくつか投稿してきた、.NET FrameworkとMonoにおけるGetFullPathとかnew Uriの挙動の違いについてである。

<iframe src="http://www.slideshare.net/slideshow/embed_code/35913754" width="427" height="356" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC; border-width:1px 1px 0; margin-bottom:5px; max-width: 100%;" allowfullscreen> </iframe> <div style="margin-bottom:5px"> <strong> <a href="https://www.slideshare.net/masatokunita/coins-lt0-miocatshortpublic" title="tkbctf3 miocatができるまで 〜あるいは.NET FrameworkがWindows向けであることを（今更）確信するに至るまで〜" target="_blank">tkbctf3 miocatができるまで 〜あるいは.NET FrameworkがWindows向けであることを（今更）確信するに至るまで〜</a> </strong> from <strong><a href="http://www.slideshare.net/masatokunita" target="_blank">Masato Kunita</a></strong> </div>

実際の発表時の動画も公開されている。だいたい07:58あたりからが私の発表である。

<iframe width="560" height="315" src="//www.youtube-nocookie.com/embed/s3_BCaFAVv8" frameborder="0" allowfullscreen></iframe>

「小傘ちゃんかわいい」のところでなぜか拍手が起こったり（これは後で原因がわかった）、ぼちぼち笑いが取れていたように思う。

さて、それはともかくとして実は前に投げたバグレポートに返事がついていて、状態はRESOLVED INVALIDとなっていた。

曰く、「"http://test.com" はUnixでは妥当なファイルパスである。.NETはUnixに対する考慮が足りてないからそういう挙動になるんであって、つまりお前のコードで対処しろ」。

全くの正論であった。そもそもユーザーから与えられた文字列をそのままDownloadStringとかに投げている時点で結構異常なので、ちゃんと入力はチェックしましょう、という結論に至った。

Unixで妥当なら仕方ないね、と私は思ったし、今述べたように事前にチェックすべきだと考えるので私はこのままでいいんじゃないかと思っている。