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

xcode_derived_data := ".xcodeDerivedData"
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
    if [ -n "{{FILTER}}" ]; then
        swift test --parallel --filter "{{FILTER}}"
    else
        swift test --parallel
    fi

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

_xcodebuild project_type project scheme *ARGS:
    @just swift-version
    xcodebuild \
        -derivedDataPath "{{xcode_derived_data}}" \
        -destination 'generic/platform=macOS' \
        -{{project_type}} "{{project}}" \
        -scheme "{{scheme}}" \
        {{ARGS}} \
        {{xcode_formatter}}

_xcodebuild-sample-app *ARGS:
    @just _xcodebuild "project" "{{xcode_project}}" "{{xcode_scheme}}" {{ARGS}}
