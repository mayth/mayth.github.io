---
layout: post
title: "Different Behaviors of DownloadString and Uri between .NET and Mono"
date: 2014-05-08 07:43:38 +0900
comments: true
categories: 
  - .NET
  - Mono
---

Note: This is the summary of my posts (they are written in Japanese):

* [tkbctf3 Miocat](http://tech.aquarite.info/blog/2014/05/07/tkbctf3-miocat/)
* [MonoのWebClientにおけるURI](http://tech.aquarite.info/blog/2014/05/07/uri-parsing-in-webclient/)
* [結局Monoと.NETの挙動の違いはなんだったのか](http://tech.aquarite.info/blog/2014/05/08/download-string-in-mono-and-dotnet-framework/)

I already reported this as a bug for Xamarin's Bugzilla.

# Introduction

I found the different behavior of `WebClient.DownloadString(String)` between Mono and .NET Framework when an invalid URI passed to it. In the Mono's implementation, it may cause a security issue.

This causes by two different behaviors, in `new Uri(String)`, and `Path.GetFullPath(String)`.

# DownloadString

`DownloadString(String)` and some methods (e.g. `DownloadFile(String)`, `OpenRead(String)`, etc.) calls `CreateUri(String)`, a private method of `WebClient`. (-> [source code on github](https://github.com/mono/mono/blob/master/mcs/class/System/System.Net/WebClient.cs#L798))

## CreateUri and GetUri

`CreateUri(String)` tries to make an instance of `Uri` with `new Uri(String)`. If an invalid URI passed, the constructor raises an exception. For example, `new Uri("http://../../../etc/passwd")` will be failed because its hostname part (`..`) is invalid. However, the failure will be ignored, and `CreateUri(String)` returns `new Uri(Path.GetFullPath(String))`. It means the local file address with the full path will be returned.

In .NET Framework, `DownloadString(String)` calls `GetUri(String)`, and it may have the same behavior as `CreateUri(String)`. (I didn't read its implementation, but I guess it from the stack trace when an exception is thrown.)

# Uri constructor

In .NET, `new Uri(String)` fails when an invalid URI with a known scheme is given (e.g. `http://../../etc/passwd`), however, it *succeeds* when a invalid URI with *an unknown scheme* is given (e.g. `abc://../../etc/passwd`).

In Mono, `new Uri(String)` fails for both cases.

This is the first different behavior.

# Path.GetFullPath

While `Path.GetFullPath` fails for URIs which has known schemes in .NET, it succeeds for any URIs in Mono.

For example, `http://../etc/passwd` is given, .NET's `Path.GetFullPath` fails with ArgumentException ("URI formats are not supported."), but Mono's succeeds and returns the full path like `/home/mayth/etc/passwd`.

Another example: `abc://../etc/passwd` is given, .NET's `Path.GetFullPath` will succeeds, and Mono's also succeeds.

This result shows that .NET's implemantation may recognize the scheme of the given URI, and Mono's one may not.

This is the second different behavior.

# The Flow of DownloadString(String)

## .NET

### Invalid URIs with known scheme

By default, 'known scheme' means these schemes:

* http://
* https://
* ftp://
* file://

This is documented on MSDN (See: [WebRequest.Create Method (String)](http://msdn.microsoft.com/en-us/library/bw00b1dc.aspx)).

parameter: addr = `http://../../etc/passwd`

1. `GetUri(addr)` is called
2. Try to `new Uri(addr)`, and it fails
3. An exception is ignored, and `Path.GetFullPath(addr)` is called
4. `Path.GetFullPath(addr)` throws ArgumentException with the message: "URI formats are not supported."

### Invalid URIs with unknown scheme

parameter: addr = `abc://../../etc/passwd`

1. `GetUri(addr)` is called
2. Try to `new Uri(addr)`, and it succeeds.
3. `GetUri(addr)` returns the result of step2.
4. `WebRequest.Create` is called.
5. It throws NotSupportedException because it does not know how to handle the given URI's scheme.

## Mono

In Mono, there is no difference whether the URI's scheme is known or not.

parameter: addr = `http://../../etc/passwd`

1. `GetUri(addr)` is called
2. Try to `new Uri(addr)`, and it fails
3. An exception is ignored, and `Path.GetFullPath(addr)` is called
4. `Path.GetFullPath(addr)` returns the full path (e.g. `/home/etc/passwd`)
5. The full path passed to `new Uri(String)`. This may result `file:///home/etc/passwd`.
6. Attempt to acquire the resource, `file:///home/etc/passwd`.

# Security Issue

Like the samples shown above, `DownloadString(String)` can access to the local resource, like `/etc/passwd`.

## Directory Traversal

If the program runs at /home/mayth, for example, the code below will returns the content of `/etc/passwd`.

```
WebClient.DownloadString("http://../../../etc/passwd")
```

Of course, any files that is readable from the user who runs the program can be read. For example, the files in the home directory can be read.

The attackers can't know the listings of the directory, but they suggest it, or guess from `.bash_history` file.

## Full Path Disclosure

If the program runs at `/home/mayth`, the code below will fail because it won't be found.

```
WebClient.DownloadString("http://../../etc/passwd")
```

In this case, an exception's message is: 'Could not find a part of the path "/home/etc/passwd"'. If you output this message somewhere (stdout, log file, etc.), the attackers may be possible to see the full path.