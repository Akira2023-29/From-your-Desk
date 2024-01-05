#!/bin/bash
set -e

# Rails に対応したファイル server.pid が存在しているかもしれないので削除する。
rm -f /app/tmp/pids/server.pid

# デプロイ時にプリコンパイル、データベースのマイグレーション実行。
bundle exec rails assets:precompile
bundle exec rails db:migrate

# コンテナーのプロセスを実行する。（Dockerfile 内の CMD に設定されているもの。）
exec "$@"