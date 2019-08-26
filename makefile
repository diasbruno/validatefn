NODE_BINS_PATH=./node_modules/.bin

NYC=$(NODE_BINS_PATH)/nyc
MOCHA=$(NODE_BINS_PATH)/mocha
BABEL=$(NODE_BINS_PATH)/babel
UGLIFYJS=$(NODE_BINS_PATH)/uglifyjs

BRANCH=$(shell git rev-parse --abbrev-ref HEAD)
CURRENT_VERSION:=$(shell jq ".version" package.json)

ifdef RELEASE
VERSION:=$(shell read -p "Release $(CURRENT_VERSION) -> " VERSION && echo $$VERSION)
endif

OPTS=

ifdef DEBUG
	OPTS += -w
endif

.PHONY: all
all:
	$(BABEL) src -d .

.PHONY: release-commit
release-commit:
	@echo "* Release $(CURRENT_VERSION) -> $(VERSION)"
	git add .
	git commit -m "Release $(VERSION)."

. PHONY: release-tag
release-tag:
	@echo "* Tag"
	git tag "$(VERSION)"

.PHONY: publish-version
publish-version: release-commit release-tag
	@echo "* Publishing"
	git push upstream "$(BRANCH)" "$(VERSION)"

.PHONY: publish-on-npm
publish-on-npm:
	@echo "* Publishing on npm"
	npm publish

.PHONY: update-package-version
update-package-version:
	@echo "* Updating package version"
	jq 'setpath(["version"]; "$(VERSION)")' < package.json > tmp.json
	mv -f tmp.json package.json

.PHONY: compressing
compressing:
	@echo "* Compressing"
	$(UGLIFYJS) --rename -m < index.js > tmp.js
	mv -f tmp.js index.js

.PHONY: standalone-version
standalone-version:
	@echo "* Standalone version"
	rm -rf dist/*
	echo "/* check-fns $(VERSION) */" > tmp.js
	$(UGLIFYJS) index.js --rename -m -ie8 >> tmp.js
	mv -f tmp.js dist/check-fns-$(VERSION).js

.PHONY: build
build: all tests standalone-version compressing

.PHONY: publishing
publishing: build update-package-version publish-version publish-on-npm

.PHONY: publish
publish:
	RELEASE=1 make -C . publishing

tests:
	$(NYC) --check-coverage --all mocha tests.js
clean:
	rm -rf index.js
