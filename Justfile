alias b := build
alias t := test
alias f := fmt
alias c := clean
alias r := run

run:
    swift run

build:
    swift build

test:
    swift test

clean:
    rm -rf .build

fmt:
    swiftformat .
