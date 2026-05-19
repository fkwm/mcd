.PHONY: help up down shell clean

# コンテナエンジン選択（docker / podman）
ENGINE ?= docker

# コンテナ名・イメージ
# コンテナ名にはプロジェクトの絶対パスから生成した 8 桁ハッシュを含める。
# これによりディレクトリごとに別のコンテナとなり、別プロジェクトで作成された
# 同名コンテナのマウント情報が誤って再利用される事故を防ぐ。
# printf を使うのは echo -n が一部の sh で非対応なため。
PROJECT_HASH   := $(shell printf '%s' "$(CURDIR)" | md5sum | cut -c1-8)
CONTAINER_NAME := mcd-test-$(PROJECT_HASH)
CONTAINER_IMAGE := busybox:latest

# エンジンごとの差異を吸収
ifeq ($(ENGINE),podman)
  CONTAINER_EXISTS = podman container exists $(CONTAINER_NAME)
  ENGINE_OPTS      = --userns=keep-id
else
  CONTAINER_EXISTS = docker container inspect $(CONTAINER_NAME) > /dev/null 2>&1
  ENGINE_OPTS      =
endif

# デフォルトターゲット
help:
	@echo "================================================================"
	@echo "  mcd テストシステム"
	@echo "================================================================"
	@echo ""
	@echo "  mcd.sh を busybox コンテナ内でテストします。"
	@echo "  コンテナ内から ../src が /app/src としてマウントされます。"
	@echo ""
	@echo "----------------------------------------------------------------"
	@echo "  コンテナエンジン"
	@echo "----------------------------------------------------------------"
	@echo ""
	@echo "  デフォルトは docker を使用します。"
	@echo ""
	@echo "    例: make test"
	@echo ""
	@echo "  podman に切り替えるには ENGINE=podman を付与します。"
	@echo ""
	@echo "    例: make test ENGINE=podman"
	@echo ""
	@echo "  現在のエンジン: $(ENGINE)"
	@echo ""
	@echo "----------------------------------------------------------------"
	@echo "  コマンド一覧"
	@echo "----------------------------------------------------------------"
	@echo ""
	@echo "  make (引数なし)"
	@echo "    このヘルプを表示します。"
	@echo ""
	@echo "  make shell [ENGINE=docker|podman]"
	@echo "    コンテナ内で対話シェル (sh) を起動します。"
	@echo "    手動でコマンドを確認したいときに使用します。"
	@echo "    ../src が /app/src にマウントされているため、"
	@echo "    コンテナ内で以下のように mcd.sh を読み込めます:"
	@echo "      source /app/src/mcd.sh"
	@echo ""
	@echo "  make up [ENGINE=docker|podman]"
	@echo "    コンテナを起動します。初回はイメージの pull と作成を行います。"
	@echo "    test / shell は自動で up を呼び出すため通常は直接使用不要です。"
	@echo ""
	@echo "  make down [ENGINE=docker|podman]"
	@echo "    起動中のコンテナを停止します。"
	@echo ""
	@echo "  make clean [ENGINE=docker|podman]"
	@echo "    コンテナを停止・削除します。"
	@echo ""
	@echo "================================================================"

# コンテナを起動 (初回作成 or start)
up:
	@if ! $(CONTAINER_EXISTS); then \
		echo "コンテナを作成して起動します: $(CONTAINER_NAME) ($(ENGINE))"; \
		$(ENGINE) run -d \
			--name $(CONTAINER_NAME) \
			--stop-signal SIGKILL \
			$(ENGINE_OPTS) \
			-v "$(CURDIR)/../src:/app/src" \
			-w /app \
			$(CONTAINER_IMAGE) \
			sleep infinity > /dev/null; \
	else \
		echo "コンテナを起動します: $(CONTAINER_NAME) ($(ENGINE))"; \
		$(ENGINE) start $(CONTAINER_NAME) > /dev/null; \
	fi

# コンテナを停止
down:
	@$(ENGINE) stop $(CONTAINER_NAME) > /dev/null

# コンテナ内でシェルを起動
shell: up
	@$(ENGINE) exec -it $(CONTAINER_NAME) /bin/sh

# コンテナを停止・削除
clean:
	@$(ENGINE) stop $(CONTAINER_NAME) > /dev/null 2>&1 || true
	@$(ENGINE) rm $(CONTAINER_NAME) > /dev/null 2>&1 || true
	@echo "✓ コンテナを削除しました: $(CONTAINER_NAME)"
