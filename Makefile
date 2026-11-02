VERSION_TMPL=Sources/Sbar/Version.swift.tmpl
VERSION_FILE=Sources/Sbar/Version.swift

build:
	@swift build
	@sh scripts/package-eventkit-helper.sh "$$(swift build --show-bin-path)"

release:
	@swift build --configuration release --disable-sandbox
	@sh scripts/package-eventkit-helper.sh "$$(swift build --configuration release --show-bin-path)"

format:
	@swift format format -r -i Sources Tests Package.swift

lint:
	@swift format lint -r Sources Tests Package.swift

test:
	@swift test --no-parallel --disable-xctest

clean:
	@swift package clean

bump_version:
	@sed 's/__VERSION__/$(NEW_VERSION)/g' $(VERSION_TMPL) > $(VERSION_FILE)

.DEFAULT_GOAL := build
.PHONY: build release format lint test clean bump_version
