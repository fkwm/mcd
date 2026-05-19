mmcd() {
  # $HOME 配下かチェック
  case "$PWD" in
    $HOME|$HOME/*)
      ;;
    *)
      echo "$HOME 配下ではないため実行できません: $PWD"
      return 1
      ;;
  esac

  # $PWD から $HOME まで遡りながら tmp ディレクトリを探す
  mmcd_search_dir=$PWD
  mmcd_note_dir_base=""
  while true; do
    if [ -d "$mmcd_search_dir/tmp" ]; then
      mmcd_note_dir_base=$mmcd_search_dir/tmp
      break
    fi
    if [ "$mmcd_search_dir" = "$HOME" ]; then
      break
    fi
    mmcd_search_dir=$(dirname "$mmcd_search_dir")
  done

  if [ -z "$mmcd_note_dir_base" ]; then
    printf "tmpディレクトリが存在しません。 %s/tmp を作成しますか？ [y/N]: " "$PWD"
    read mmcd_ans
    case "$mmcd_ans" in
      [yY]|[yY][eE][sS])
        mkdir -p "$PWD/tmp"
        mmcd_note_dir_base=$PWD/tmp
        ;;
      *)
        return 1
        ;;
    esac
  fi

  MCD_NOTE_DIR_BASE=$mmcd_note_dir_base mcd "$@"
}

mcd() {
  # zoxide (z コマンド) が利用可能かチェック
  if command -v z >/dev/null 2>&1; then
    CMD_CD=z
  else
    CMD_CD=cd
  fi

  case "$1" in
    -h|--help)
      cat <<'EOF'
----------------------------------------------------------------------
  mcd - 日毎のメモディレクトリ作成・移動コマンド ver0.6
----------------------------------------------------------------------
概要:
  日付(YYYYMMDD形式)のディレクトリを作成し、そのディレクトリに移動します。
  ディレクトリが存在しない場合は自動的に作成され、memo.txt ファイルも
  初期化されます。

動作環境:
  コンテナ等を含めほとんどのLinux環境で動作するよう
  busybox の sh でも動作するよう調整しています。
設定方法(例):
  ~/.bashrc や ~/.profile などに以下を記載:
   source /path/to/mcd.sh
   併せて下記環境変数を適切に設定してください。

使用方法:
  [基本]
  $ mcd
  → $HOME/tmp/20260102 に移動
     * 実行日が2026年1月2日の場合
     * $MCD_NOTE_DIR_BASE を設定していないか $HOME/tmp に設定した場合
  → ディレクトリが存在しない場合は作成され、memo.txt も初期化されます

  [N項目前の記録に移動]
  $ mcd -1
  → 1つ前の記録ディレクトリに移動（探索モード）
  → カレントディレクトリが 20260102 の場合、20260101 に移動
     (20260101が無い場合はその前に移動)
  → ディレクトリ作成、memo.txt 作成、テンプレート展開は行いません
  → 8桁数字で始まるディレクトリをソートして使用しています
     20260105 20260104 20260104.test 20260103 というディレクトリがあった場合は
     20260105 > 20260104.test > 20260104 > 20260103 となります。

  [N項目後の記録に移動]
  $ mcd +1
  → 1つ後の記録ディレクトリに移動（探索モード）
  → カレントディレクトリが 20260102 の場合、20260103 に移動
     (20260103が無い場合はその後に移動)
  → 他詳細については[N項目前の記録に移動]とルールは同じです。

  [MCD_NOTE_DIR_BASEを設定する場合]
  $ MCD_NOTE_DIR_BASE=$HOME/notes mcd
  → $HOME/notes/20260102 に移動(2026/01/02 に実行した場合)

  [応用]
  # コマンドを短縮
  alias t="mcd"
  # よく使うコマンドを登録
  alias tt="mcd -1"
  alias tp="mcd -1"
  alias tn="mcd +1"

環境変数:
  通常の環境変数です。上の例のように指定の上実行する他、
  ~/.bashrc などに設定してください。

  MCD_NOTE_DIR_BASE  メモディレクトリのベースとなるディレクトリ
                      (デフォルト: $HOME/tmp)

  MCD_TEMPLATE_DIR   テンプレートディレクトリのパス
                      設定されている場合、そのディレクトリ内のファイルや
                      ディレクトリを新規作成時にコピーします。
                      設定されているに関わらずディレクトリが
                      存在しない場合は警告を表示し、
                      デフォルトの memo.txt を作成します。
                      (デフォルト: 未設定)

EOF
      return 0
      ;;
    -[0-9]*)
      # N日前の記録に移動（探索モード）
      offset=${1#-}
      note_dir_base=${MCD_NOTE_DIR_BASE:-$HOME/tmp}

      # カレントディレクトリから base_date を取得
      current_dir=$PWD
      case "$current_dir" in
        $note_dir_base/*)
          # note_dir_base からの相対パスを取得
          rel_path=${current_dir#$note_dir_base/}
          # 最初のディレクトリ要素を取得
          first_dir=${rel_path%%/*}
          # 8桁数字から始まるかチェック
          case "$first_dir" in
            [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*)
              base_date=$first_dir
              ;;
            *)
              base_date=`date +'%Y%m%d'`
              ;;
          esac
          ;;
        *)
          base_date=`date +'%Y%m%d'`
          ;;
      esac

      # ディレクトリ一覧を取得（8桁の数字で始まる）し、降順ソート
      dir_list=$(ls -1 $note_dir_base 2>/dev/null | grep '^[0-9]\{8\}' | sort -r)

      # base_date より小さいディレクトリのうち offset 番目を取得
      target_dir=$(echo "$dir_list" | awk -v base="$base_date" -v offset="$offset" '
        $1 < base {
          count++
          if (count == offset) {
            print $1
            exit
          }
        }
      ')
      if [ -z "$target_dir" ]; then
        echo "エラー: ${offset}日前のディレクトリが見つかりません"
        return 1
      fi

      $CMD_CD $note_dir_base/$target_dir
      return 0
      ;;
    +[0-9]*)
      # N日後の記録に移動（探索モード）
      offset=${1#+}
      note_dir_base=${MCD_NOTE_DIR_BASE:-$HOME/tmp}

      # カレントディレクトリから base_date を取得
      current_dir=$PWD
      case "$current_dir" in
        $note_dir_base/*)
          # note_dir_base からの相対パスを取得
          rel_path=${current_dir#$note_dir_base/}
          # 最初のディレクトリ要素を取得
          first_dir=${rel_path%%/*}
          # 8桁数字から始まるかチェック
          case "$first_dir" in
            [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*)
              base_date=$first_dir
              ;;
            *)
              base_date=`date +'%Y%m%d'`
              ;;
          esac
          ;;
        *)
          base_date=`date +'%Y%m%d'`
          ;;
      esac

      # ディレクトリ一覧を取得（8桁の数字で始まる）し、昇順ソート
      dir_list=$(ls -1 $note_dir_base 2>/dev/null | grep '^[0-9]\{8\}' | sort)

      # base_date より大きいディレクトリのうち offset 番目を取得
      target_dir=$(echo "$dir_list" | awk -v base="$base_date" -v offset="$offset" '
        $1 > base {
          count++
          if (count == offset) {
            print $1
            exit
          }
        }
      ')

      if [ -z "$target_dir" ]; then
        echo "エラー: ${offset}日後のディレクトリが見つかりません"
        return 1
      fi

      $CMD_CD $note_dir_base/$target_dir
      return 0
      ;;
    "")
      # 引数なし（今日）
      ;;
    *)
      echo "エラー: 不正な引数 '$1'"
      return 1
      ;;
  esac

  date_line=`date +'%Y%m%d'`
  note_dir_base=${MCD_NOTE_DIR_BASE:-$HOME/tmp}
  note_dir=$note_dir_base/$date_line
  note_template_dir=${MCD_TEMPLATE_DIR:-}

  if [ ! -d $note_dir ]; then
    mkdir -p $note_dir
  fi

  if [ ! -e $note_dir/memo.txt ]; then
    if [ -n "$note_template_dir" ]; then
      if [ -d "$note_template_dir" ]; then
        cp -r $note_template_dir/* $note_dir/ 2>/dev/null || true
      else
        echo "Can't find $note_template_dir"
        echo -ne "# -*- coding: utf-8-unix; -*-\n" > $note_dir/memo.txt
      fi
    else
      echo -ne "# -*- coding: utf-8-unix; -*-\n" > $note_dir/memo.txt
    fi
  fi
  $CMD_CD $note_dir
}
