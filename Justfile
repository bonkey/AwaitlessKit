alias b := build
alias b5 := build-swift5
alias b6 := build-swift6
alias t := test
alias f := fmt
alias c := clean

alias r := run-sample-app
alias rb := run-and-build-sample-app

swift_toolchain_510 := "org.swift.5101202403041a"
swift_toolchain_610 := "org.swift.610202503301a"
swift_build_dir := ".build"

package_workspace := ".swiftpm/xcode/package.xcworkspace"
package_scheme := "AwaitlessKit"

xcode_derived_data := ".xcodeDerivedData"
xcode_project := "SampleApp/SampleApp.xcodeproj"
xcode_scheme := "SampleApp"
xcode_formatter := `if command -v xcbeautify >/dev/null 2>&1; then echo "| xcbeautify"; elif command -v xcpretty >/dev/null 2>&1; then echo "| xcpretty"; else echo ""; fi`

build-swift6:
    @just build "{{swift_toolchain_610}}"

build-swift5:
    @just build "{{swift_toolchain_510}}"

build toolchain="com.apple.dt.toolchain.XcodeDefault":
    @just swift-version "{{toolchain}}"
    xcrun --toolchain "{{toolchain}}" swift build

swift-version toolchain:
    @echo "{{ style('warning') }}$(xcrun --toolchain '{{toolchain}}' swift -version){{ NORMAL }}"

test:
    swift test

clean toolchain="com.apple.dt.toolchain.XcodeDefault":
    swift package clean
    @just resolve-package "{{toolchain}}"
    @just resolve-sample-app "{{toolchain}}"

reset:
    swift package reset
    rm -rf "{{xcode_derived_data}}"

fmt:
    swiftformat .

build-sample-app-swift6:
    @just build-sample-app "{{swift_toolchain_610}}"

build-sample-app-swift5:
    @just build-sample-app "{{swift_toolchain_510}}"

xcodebuild project_type project scheme toolchain="com.apple.dt.toolchain.XcodeDefault" *ARGS:
    @just swift-version "{{toolchain}}"
    xcrun --toolchain "{{toolchain}}" xcodebuild \
        -derivedDataPath "{{xcode_derived_data}}" \
        -destination 'generic/platform=macOS' \
        -{{project_type}} "{{project}}" \
        -scheme "{{scheme}}" \
        {{ARGS}} \
        {{xcode_formatter}}

xcodebuild-sample-app toolchain="com.apple.dt.toolchain.XcodeDefault" *ARGS:
    @just xcodebuild "project" "{{xcode_project}}" "{{xcode_scheme}}" "{{toolchain}}" {{ARGS}}

xcodebuild-package toolchain="com.apple.dt.toolchain.XcodeDefault" *ARGS:
    @just xcodebuild "workspace" "{{package_workspace}}" "{{package_scheme}}" "{{toolchain}}" {{ARGS}}

resolve-sample-app toolchain="com.apple.dt.toolchain.XcodeDefault":
    @just xcodebuild-sample-app "{{toolchain}}" -resolvePackageDependencies clean

resolve-package toolchain="com.apple.dt.toolchain.XcodeDefault":
    @just xcodebuild-package "{{toolchain}}" -resolvePackageDependencies clean

build-sample-app toolchain="com.apple.dt.toolchain.XcodeDefault":
    @just xcodebuild-sample-app "{{toolchain}}" build

run-sample-app:
    "{{xcode_derived_data}}/Build/Products/Debug/SampleApp"

run-and-build-sample-app: build-sample-app run-sample-app
