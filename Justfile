alias b := build
alias t := test
alias f := fmt
alias c := clean

alias r := run-sample-app
alias rb := run-and-build-sample-app

swift_build_dir := ".build"
xcode_build_dir := ".xcodeDerivedData"

build:
    swift build

test:
    swift test

clean:
    rm -rf "{{swift_build_dir}}" "{{xcode_build_dir}}"

fmt:
    swiftformat .

build-sample-app:
    #!/usr/bin/env zsh
    xcodebuild_args=(
        -project SampleApp/SampleApp.xcodeproj
        -scheme SampleApp
        -configuration Debug
        -derivedDataPath "{{xcode_build_dir}}"
    )

    if command -v xcbeautify >/dev/null 2>&1; then
        xcrun xcodebuild "${xcodebuild_args[@]}" | xcbeautify
    elif command -v xcpretty >/dev/null 2>&1; then
        xcrun xcodebuild "${xcodebuild_args[@]}" | xcpretty
    else
        xcrun xcodebuild "${xcodebuild_args[@]}"
    fi

run-sample-app:
    "{{xcode_build_dir}}/Build/Products/Debug/SampleApp"

run-and-build-sample-app: build-sample-app run-sample-app
