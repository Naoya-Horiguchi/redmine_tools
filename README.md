このツールは、RedMine をターミナルベースで効率よく扱うことを目的とした支援ツールです。チケットの作成・編集・表示・整形を手元の Linux のターミナル環境で実行できます。

## 事前準備/初回設定

* `jq` と `gawk` をインストールする。
* 対象となる RedMine 上の URL と API key を確認する。
* bash 形式の設定ファイル (`environment` を参考に) に環境変数をセットして source しておく。
* `~/.bashrc` から `redmine.bash` を source する。
* 初回設定時は `redmine config --update` で対象 RedMine サーバ固有の情報を取得する。

上記準備が完了すれば、チケットの一覧 (list)・閲覧 (show)・作成 (new)・編集 (edit) などの通常の操作を実行できる。

## サブコマンド・使い方

使用可能なサブコマンドのリストは `redmine help` コマンドで表示できる。

~~~
$ redmine

  Usage:
    redmine [global options] <subcmd> [options]

  Global options (GLOBAL_VARIABLE)
    -c config_file  specify config file including set of configurations
    -d dir          directory to store config and ticket cache (RM_CONFIG)
    -u base_url     base URL of target RedMine server (RM_BASEURL)
    -k api_key      API key to access to the RedMine (RM_KEY)
    -f format       markup language used by the RedMine (textile or markdown: RM_FORMAT)
    -e editor       your text editor (EDITOR)
    --insecure      skip verification of the certificate for HTTPS connection (INSECURE)
    --color         display with colored output

  Supported subcommands:
    clock config edit help list new open remove search show tree wiki
~~~

各サブコマンドのヘルプは `redmine <subcmd> -h` で表示することができる。

### config

チケットにはプロジェクトやステータス、トラッカーなどの概念があるが、名前と ID は RedMine の設定に依存するので、初回利用時やサーバ側で変更 (プロジェクトやトラッカーを追加・更新した場合など) があった時にローカルにそれらの定義済み情報をコピーする必要がある。`redmine config --update` によりダウンロードを実行する。ダウンロードした各種情報は `redmine config <type>` により表示できる。

### new

チケットを作成する。`-t` オプションでテンプレートファイルを指定することで、既存のチケットの情報をテンプレートとして利用できる。

### list

引数・オプションを指定しなかった場合、利用ユーザがアクセスできる全てのチケットのリストを更新時刻の昇順で表示する。
~~~
$ redmine list
...
255  190621_1601        Project A           New                   Task A-1
229  190621_1638        Project B           In Progress           Task B-1
264  190621_1827        Project C           In Progress           Task C-1
L7   190621_2223        Project B           Closed                Task B-2
~~~
左からチケット ID、最終更新時刻、プロジェクト、チケット状態、チケットのサブジェクトである。引数でプロジェクト名あるいはプロジェクト ID を指定すると、指定したプロジェクトのチケットのみ表示する。`-c|-C` オプションを与えるとクローズされたチケットの表示・非表示を指定できる。クローズされたチケットの表示・非表示は環境変数 `RM_SHOW_CLOSED` を用いて指定することもでき、デフォルトは false である。`-g` オプションを与えるとプロジェクトごとにまとめてリストすることができる。引数でプロジェクトを指定したとき、配下のサブプロジェクトを全て表示したい場合は `-s` オプションを指定する。

### tree

引数で指定したプロジェクト名あるいはプロジェクト ID の配下のチケットをツリー状に表示する。`-e` オプションを指定するとエディタでツリー構造を編集し、チケットの作成や編集 (階層構造、トラッカ、状態、件名) を複数チケットに対してまとめて実施できる。

### show

指定したチケット番号の draft を表示する。Markdown 形式などをベースに他形式にフォーマット変換したい場合などに便利かもしれない。`-t` オプションを指定すると、指定したチケットのサブチケットをまとめて一つのテキストファイルとして取り出すことができる。`-T` オプションでチケット構造をファイルから入力して一つのテキストファイルとして出力できる。入力するチケット構造は `redmine tree` コマンドの出力に似たフォーマットに従う。

### edit

指定したチケット番号の draft を表示・編集する。編集後、更新内容がある場合に RedMine サーバへのアップロードを実行する。環境変数 `RM_TIME_ENTRY` を true に設定している場合、編集のためにエディタを開いていた時間に基づき、チケットに「作業時間」を作成・付与する。

`-f` オプションを用いると、指定したファイルを draft ファイルとして入力することができる。`redmine show` コマンドと組み合わせると「ドラフトファイルの出力→スクリプト処理→サーバーにアップロード」といった流れでチケットの編集を自動化できるようになる。なお、`redmine show` の出力はデフォルトで変更履歴情報がついてくるので、この目的でドラフトファイルを出力させる際は環境変数 `RM_SHOW_JOURNALS` を `false` に設定する必要がある。

### attach

`redmine attach -l` で Redmine サーバ上の添付ファイルの URL 一覧を取得できる。 `redmine attach <ticketID> <path/URL>` のようなコマンドにより、指定したチケットにファイルをアタッチできる。添付したいファイルはローカルのファイルパスでもよいし、"http... " で指定されるウェブ上の URL を指定してもよい。

### clock

redmine new/edit でチケットを編集している間、開始時間と終了時間を記録しているので、そこからクロック (その作業に費やした時間) を計算できる。
クロックは基本的に開始から終了までの時間だが、他のチケットを同時にオープンした期間がある場合は、重複期間をオープンしていたチケットの数で割って計算する。

例えば下記のような出力が得られる。
~~~
$ redmine clock
Clock during [2019/06/24, 2019-06-24T23:59:00+09:00)
246  1    project A          Task A-1
241  13   project A          Task A-2
276  94   project A          Task A-3
L9   259  private_project    private task
---  ---  ---                ---
     109  project A          // プロジェクトごとのクロック
     259  private_project
---  ---  ---                ---
     369  total              // 総クロック
~~~

引数なしの場合は今日のクロックを表示する。
引数が 1 つの場合は指定した日のクロックを表示する。
引数が 2 つの場合は指定した期間のクロックを表示する。
~~~
$ redmine clock                         // 今日のクロックの表示
$ redmine clock 2019/06/20              // 指定した日のクロックを表示
$ redmine clock 06/20 06/23             // 指定した期間のクロックを表示
$ redmine clock "a week ago" "today"    // date コマンドの -d オプションが認識する方法で入力可能
~~~

### open

指定したチケットをブラウザで表示する。

### remove

指定したチケットを削除する。

### search

引数で入力した文字列を RedMine サーバ上で検索する。`-o` を指定するとクローズされたチケットを検索対象から除外する。

### wiki

指定したプロジェクトの wiki ページを表示・編集できる。`redmine wiki -l <pj>` コマンドにより指定したプロジェクトの wiki ページリストを表示できる。ここに表示される WikiPage 名を用いて `redmine wiki <pj> <WikiPage>` を実行すると、指定した Wiki ページをエディタで編集できる。

## データ構造

現時点で、REST API から取得した json ファイルをファイルとしてローカルキャッシュに保存して高速化しているが、改善の余地がある。
