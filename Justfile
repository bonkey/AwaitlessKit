alias b := build
alias t := test
alias f := fmt

build:
    swift build

test:
    swift test

clean:
    rm -rf .build

fmt:
    swiftformat .
