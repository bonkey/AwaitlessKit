alias b := package-build
alias t := package-test

alias f := fmt
alias c := all-clean
alias clean := all-clean

alias reset := all-reset

alias r := sample-app-run
alias br := sample-app-build-and-run
alias o := sample-app-open

swift_build_dir := ".build"

package_workspace := ".swiftpm/xcode/package.xcworkspace"
package_scheme := "AwaitlessKit"

xcode_derived_data := ".xcode/derivedData"
xcode_project := "SampleApp/SampleApp.xcodeproj"
xcode_scheme := "SampleApp"
xcode_formatter := `if command -v xcbeautify >/dev/null 2>&1; then echo "| xcbeautify -q"; elif command -v xcpretty >/dev/null 2>&1; then echo "| xcpretty"; else echo ""; fi`

kill-xcode:
    -pkill -9 Xcode

package-build:
    @just swift-version
    swift build

swift-version:
    @echo "$(swift -version)"

package-test *FILTER:
    #!/usr/bin/env bash
    coverage_flag=""
    if [ "${REPORT_TESTING:-false}" = "true" ]; then
        coverage_flag="--enable-code-coverage --xunit-output awaitlesskit.junit"
    fi

    if [ -n "{{FILTER}}" ]; then
        set -x
        swift test --parallel $coverage_flag --filter "{{FILTER}}"
    else
        set -x
        swift test --parallel $coverage_flag
    fi

full-clean: kill-xcode
    rm -rf .build .xcode

all-clean: kill-xcode
    swift package clean
    @just package-resolve
    @just sample-app-resolve

fmt:
    swiftformat .

package-reset:
    swift package reset

all-reset: package-reset sample-app-reset

package-info:
    swift package describe --type json | jq .

package-deps:
    swift package show-dependencies

package-resolve:
    swift package resolve

sample-app-reset:
    rm -rf "{{xcode_derived_data}}"

sample-app-resolve:
    @just _xcodebuild-sample-app -resolvePackageDependencies clean

sample-app-build:
    @just _xcodebuild-sample-app build

sample-app-run:
    "{{xcode_derived_data}}/Build/Products/Debug/SampleApp"

sample-app-build-and-run: sample-app-build sample-app-run

sample-app-open:
    open "{{xcode_project}}"

# ---------------------

_xcodebuild scheme destination *ARGS:
    @just swift-version
    xcodebuild \
        -derivedDataPath "{{xcode_derived_data}}" \
        -clonedSourcePackagesDirPath .xcode/clonedSourcePackages \
        -destination "{{destination}}" \
        -scheme "{{scheme}}" \
        {{ARGS}} \
        {{xcode_formatter}}

_xcodebuild-sample-app *ARGS:
    @just _xcodebuild "{{xcode_scheme}}" "generic/platform=macOS" -project "{{xcode_project}}" {{ARGS}}

_xcodebuild-package destination *ARGS:
    @just _xcodebuild "{{package_scheme}}" "{{destination}}" -skipMacroValidation -skipPackagePluginValidation {{ARGS}}

coverage-lcov OUTPUT_FILE="coverage.lcov":
    #!/usr/bin/env bash
    PROFDATA="$(find .build -name 'default.profdata' | head -n 1)"
    XCTEST_PATH="$(find .build -name '*.xctest' | head -n 1)"
    COV_BIN="${XCTEST_PATH}/Contents/MacOS/$(basename "$XCTEST_PATH" .xctest)"

    xcrun llvm-cov export \
        "${COV_BIN}" \
        -instr-profile="$PROFDATA" \
        -ignore-filename-regex=".build|Tests" \
        -format=lcov > "{{OUTPUT_FILE}}"

package-build-ios:
    @just _xcodebuild-package "generic/platform=iOS" build

package-build-macos:
    @just _xcodebuild-package "platform=macOS,arch=arm64" build
