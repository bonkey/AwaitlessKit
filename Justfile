alias b := build
alias t := test
alias f := fmt
alias c := clean

alias r := run-sample-app
alias rb := run-and-build-sample-app

swift_build_dir := ".build"

package_workspace := ".swiftpm/xcode/package.xcworkspace"
package_scheme := "AwaitlessKit"

xcode_derived_data := ".xcodeDerivedData"
xcode_project := "SampleApp/SampleApp.xcodeproj"
xcode_scheme := "SampleApp"
xcode_formatter := `if command -v xcbeautify >/dev/null 2>&1; then echo "| xcbeautify -q"; elif command -v xcpretty >/dev/null 2>&1; then echo "| xcpretty"; else echo ""; fi`

kill-xcode:
    -pkill -9 Xcode

build:
    @just swift-version
    swift build

swift-version:
    @echo "{{ style('warning') }}$(swift -version){{ NORMAL }}"

test *FILTER:
    #!/usr/bin/env zsh
    if [ -n "{{FILTER}}" ]; then
        swift test --parallel --filter "{{FILTER}}"
    else
        swift test --parallel
    fi

clean: kill-xcode
    swift package clean
    @just resolve-package
    @just resolve-sample-app

reset:
    swift package reset
    rm -rf "{{xcode_derived_data}}"

fmt:
    swiftformat .

xcodebuild project_type project scheme *ARGS:
    @just swift-version
    xcodebuild \
        -derivedDataPath "{{xcode_derived_data}}" \
        -destination 'generic/platform=macOS' \
        -{{project_type}} "{{project}}" \
        -scheme "{{scheme}}" \
        {{ARGS}} \
        {{xcode_formatter}}

xcodebuild-sample-app *ARGS:
    @just xcodebuild "project" "{{xcode_project}}" "{{xcode_scheme}}" {{ARGS}}

xcodebuild-package *ARGS:
    @just xcodebuild "workspace" "{{package_workspace}}" "{{package_scheme}}" {{ARGS}}

resolve-sample-app:
    @just xcodebuild-sample-app -resolvePackageDependencies clean

resolve-package:
    @just xcodebuild-package -resolvePackageDependencies clean

build-sample-app:
    @just xcodebuild-sample-app build

run-sample-app:
    "{{xcode_derived_data}}/Build/Products/Debug/SampleApp"

run-and-build-sample-app: build-sample-app run-sample-app
