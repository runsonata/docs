#!/usr/bin/env bash

set -e

# Go to the directory containing this script
cd "$(dirname "$0")"

# Configuration
PYTHON="${PYTHON:-python3}"
PIP="$PYTHON -m pip"

case "${1:-build}" in

    install)
        echo "==> Installing/updating dependencies..."
        $PIP install -r requirements.txt
        echo "==> Done."
        ;;

    build)
        echo "==> Building MkDocs..."
        $PIP install -r requirements.txt
        $PYTHON -m mkdocs build #--strict

        echo
        echo "==> Build successful!"
        echo "Generated site: ./site/"
        ;;

    serve)
        echo "==> Installing/updating dependencies..."
        $PIP install -r requirements.txt

        echo "==> Starting MkDocs preview..."
        echo "Open http://127.0.0.1:8000 in your browser."
        echo "Press Ctrl+C to stop."

        $PYTHON -m mkdocs serve --dev-addr=127.0.0.1:8000
        ;;

    clean)
        echo "==> Removing generated site..."
        rm -rf site
        echo "==> Done."
        ;;

    *)
        echo "Usage:"
        echo "  ./docs.sh install   Install dependencies"
        echo "  ./docs.sh build     Build and check documentation"
        echo "  ./docs.sh serve     Start local preview server"
        echo "  ./docs.sh clean     Remove generated site"
        exit 1
        ;;

esac