#
# This file is part of personal-website which is released under MIT license.
# See file LICENSE.txt or go to https://github.com/matejkosiarcik/personal-website for full license details.
#

# DISCLAIMER: use '_' as prefix for private targets

### Config ###
SHELL = /bin/sh -euf
MAKEFLAGS += --warn-undefined-variables

### Setup ###
TARGET_DIR = build
DEBUG_DIR = $(TARGET_DIR)/debug
RELEASE_DIR = $(TARGET_DIR)/release

# Default target
.PHONY: all
all: format doc lint build

# Help message
.PHONY: help
help:
	@printf "%s\n" "Available targets:"
	@grep -E "^([a-z\-]+):" $(MAKEFILE_LIST) | grep -Eo "^([a-z\-]+)" | sort | tr "\n" "," | sed -E "s~(.*)~\1~" | sed -E 's~^(.+),$$~\1~' | sed "s~,~, ~g"

# Cleaning
.PHONY: clean
clean:
	rm -rf "$(TARGET_DIR)"

# Just forwarding targets
.PHONY: format
format:
	./utils/format

.PHONY: lint
lint:
	./utils/lint

# Dependency resolution
.PHONY: bootstrap
bootstrap:
	npm install

.PHONY: update
update:
	npm install --save

### Documentation ###
DOCUMENTATION_TARGET_DIR = $(TARGET_DIR)/doc
MARKDOWN_SOURCES = $(shell . "./utils/internal/helpers.sh" && files_ending ".md")
MARKDOWN_TARGETS = $(patsubst %.md, $(DOCUMENTATION_TARGET_DIR)/%.html, $(MARKDOWN_SOURCES))

$(DOCUMENTATION_TARGET_DIR)/%.html: %.md
	mkdir -p "$$(dirname $@)"
	grip "$<" --export "$@"

doc: $(MARKDOWN_TARGETS)

### Build ###
SOURCE_DIR = src
PAGES_SOURCE_DIR = $(SOURCE_DIR)/pages
PAGES_TARGET_DIR = $(DEBUG_DIR)
SHARED_SOURCE_DIR = $(SOURCE_DIR)/shared
SHARED_TARGET_DIR = $(DEBUG_DIR)/_include

.PHONY: _pre-build
_pre-build:
	@printf "%s\n" "Building into: $(DEBUG_DIR)"

## Code ##
# Markup #
# Mustache -> HTML
MARKUP_SHARED_SOURCES = $(wildcard $(SHARED_SOURCE_DIR)/markup/*.html.mustache)
MARKUP_SOURCES = $(wildcard $(PAGES_SOURCE_DIR)/**/content.html.mustache)
MARKUP_TARGETS = $(patsubst $(PAGES_SOURCE_DIR)/%/content.html.mustache, $(PAGES_TARGET_DIR)/%/index.html, $(MARKUP_SOURCES))

$(PAGES_TARGET_DIR)/%/index.html: $(PAGES_SOURCE_DIR)/%/content.html.mustache $(MARKUP_SHARED_SOURCES)
	mkdir -p "$$(dirname "$@")"
	python "./utils/internal/build-mustache.py" --data "$$(dirname "$<")" --output "$$(dirname "$@")"

_build-markup: $(MARKUP_TARGETS)

# Styles #
STYLE_SOURCE_DIR = $(SHARED_SOURCE_DIR)/styles
STYLE_TARGET_DIR = $(SHARED_TARGET_DIR)/styles

# normalize.css
NORMALIZE_SOURCE = node_modules/normalize.css/normalize.css
NORMALIZE_TARGET = $(STYLE_TARGET_DIR)/normalize.css

$(NORMALIZE_TARGET): $(NORMALIZE_SOURCE)
	mkdir -p "$$(dirname "$@")"
	cp "$<" "$@"
	printf "%s\n" "$$(cssbeautify "$@")" >"$@"

_build-normalize: $(NORMALIZE_TARGET)

# SASS -> CSS
STYLE_INTERNAL = $(wildcard $(STYLE_SOURCE_DIR)/_*.scss)
STYLE_SHARED_SOURCES = $(filter-out $(STYLE_INTERNAL), $(wildcard $(STYLE_SOURCE_DIR)/*.scss))
STYLE_SHARED_TARGETS = $(patsubst $(STYLE_SOURCE_DIR)/%.scss, $(STYLE_TARGET_DIR)/%.css, $(STYLE_SHARED_SOURCES))

$(STYLE_TARGET_DIR)/%.css: $(STYLE_SOURCE_DIR)/%.scss $(STYLE_INTERNAL)
	mkdir -p "$$(dirname "$@")"
	sass --scss --unix-newlines --style=expanded --load-path="$(STYLE_SOURCE_DIR)" "$<" "$@"
	printf "%s\n" "$$(cssbeautify "$@")" >"$@"

STYLE_PAGE_SOURCES = $(wildcard $(PAGES_SOURCE_DIR)/**/*.scss)
STYLE_PAGE_TARGETS = $(patsubst $(PAGES_SOURCE_DIR)/%.scss, $(PAGES_TARGET_DIR)/%.css, $(STYLE_PAGE_SOURCES))

$(PAGES_TARGET_DIR)/%.css: $(PAGES_SOURCE_DIR)/%.scss $(STYLE_INTERNAL)
	mkdir -p "$$(dirname "$@")"
	sass --scss --unix-newlines --style=expanded --load-path="$(STYLE_SOURCE_DIR)" "$<" "$@"
	printf "%s\n" "$$(cssbeautify "$@")" >"$@"

_build-sass: $(STYLE_SHARED_TARGETS) $(STYLE_PAGE_TARGETS)

_build-style: _build-normalize _build-sass

# Scripts #
SCRIPT_SOURCE_DIR = $(SHARED_SOURCE_DIR)/scripts
SCRIPT_TARGET_DIR = $(SHARED_TARGET_DIR)/scripts

# TypeScript -> JavaScript
SCRIPT_SHARED_INTERNAL = $(wildcard $(SCRIPT_SOURCE_DIR)/_*.ts)
SCRIPT_SHARED_SOURCES = $(filter-out $(SCRIPT_SHARED_INTERNAL), $(wildcard $(SCRIPT_SOURCE_DIR)/*.ts))
SCRIPT_SHARED_TARGETS = $(patsubst $(SCRIPT_SOURCE_DIR)/%.ts, $(SCRIPT_TARGET_DIR)/%.js, $(SCRIPT_SHARED_SOURCES))
TYPESCRIPT_FLAGS = --module "commonjs" --target "ES3" --newLine "LF" \
	--removeComments --preserveConstEnums --forceConsistentCasingInFileNames \
	--strict --alwaysStrict --strictNullChecks \
	--noEmitOnError --noImplicitAny --noImplicitThis --noImplicitReturns \
	--noUnusedLocals --noUnusedParameters --noFallthroughCasesInSwitch

$(SCRIPT_TARGET_DIR)/%.js: $(SCRIPT_SOURCE_DIR)/%.ts $(SCRIPT_SHARED_INTERNAL)
	mkdir -p "$$(dirname "$@")"
	tsc $(TYPESCRIPT_FLAGS) "$<" --outDir "$$(dirname "$@")"
	browserify "$@" --outfile "$@"

_build-typescript: $(SCRIPT_SHARED_TARGETS)

_build-scripts: _build-typescript

_build-code: _build-markup _build-style _build-scripts

## General ##
# Symlinks from / (root) to /home
MARKUP_HOME_SYMLINK_SOURCES = $(wildcard $(PAGES_TARGET_DIR)/home/*)
MARKUP_HOME_SYMLINK_TARGETS = $(patsubst $(PAGES_TARGET_DIR)/home/%, $(PAGES_TARGET_DIR)/%, $(MARKUP_HOME_SYMLINK_SOURCES))

$(PAGES_TARGET_DIR)/%: $(PAGES_TARGET_DIR)/home/%
	ln -s "home/$$(basename "$@")" "$@"

_build-symlinks: $(MARKUP_HOME_SYMLINK_TARGETS)

build: _pre-build _build-code _build-symlinks
