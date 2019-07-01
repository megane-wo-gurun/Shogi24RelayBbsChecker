将棋倶楽部24リレー交流サイトの新着投稿をチェックしてTwitterに通知するもの

### 動かし方

#### Gemパッケージを入れる

```sh
$ sudo gem install bundler
$ bundle install
```

unf_extのインストールで嵌まる場合はこのあたりを、
```
$ sudo apt install ruby-dev build-essential
```

nokogiriのインストールで怒られる場合はこのあたりを入れる。
```sh
$ sudo apt install libxml2-dev libxslt1-dev zlib1g-dev
$ sudo cpan install XML::LibXML
```

#### 環境変数を設定

```sh
$ cp env.sample.sh env.sh
```
env.sh に24のアカウントとかTwitterのアクセストークンとかを書く。

#### crontabを記述

```sh
* * * * * source $HOME/24relaybbsbot/env.sh;$HOME/24relaybbsbot/checker.rb >> $HOME/24relaybbsbot/checker.log 2>&1
```
