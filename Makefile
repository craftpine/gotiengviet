APP    := VietTelex
BUNDLE := build/$(APP).app
BIN    := $(BUNDLE)/Contents/MacOS/$(APP)
FLAGS  := -O -target arm64-apple-macos13.0
BUNDLE_ID := com.dailh.viettelex
VERSION   := 0.2
DMG       := build/$(APP)-$(VERSION).dmg

# Chữ ký ad-hoc đổi cdhash sau mỗi lần build nên macOS coi app là app khác và
# đòi cấp lại quyền Accessibility. Ký bằng cert thật thì TCC định danh app bằng
# bundle id + team, giữ nguyên quyền qua các lần build.
IDENTITY ?= $(shell security find-identity -v -p codesigning | \
              awk -F'"' '/Apple Development/ {print $$2; exit}')
ifeq ($(strip $(IDENTITY)),)
IDENTITY := -
endif

.PHONY: all build test run install dmg clean reset-perm

all: build

build: $(BIN)

$(BIN): $(wildcard Sources/*.swift) Info.plist
	@mkdir -p $(BUNDLE)/Contents/MacOS
	swiftc $(FLAGS) Sources/*.swift -o $(BIN)
	@cp Info.plist $(BUNDLE)/Contents/Info.plist
	@codesign --force --sign "$(IDENTITY)" $(BUNDLE)
	@echo "Đã build $(BUNDLE) (ký bằng: $(IDENTITY))"

test:
	@mkdir -p build
	@swiftc Sources/Telex.swift Tests/main.swift -o build/telex-tests
	@./build/telex-tests

run: build
	@pkill -x $(APP) 2>/dev/null || true
	@open $(BUNDLE)

install: build
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/
	@echo "Đã cài /Applications/$(APP).app"

# Đóng gói để mang sang máy khác. Chữ ký là Apple Development nên máy đích sẽ
# bị Gatekeeper chặn lần mở đầu — xem phần Cài đặt trong README.
dmg: build
	@rm -rf build/dmg $(DMG)
	@mkdir -p build/dmg
	@cp -R $(BUNDLE) build/dmg/
	@ln -s /Applications build/dmg/Applications
	@hdiutil create -volname "$(APP)" -srcfolder build/dmg -ov -format UDZO -quiet $(DMG)
	@rm -rf build/dmg
	@echo "Đã tạo $(DMG)"

# Xoá các mục Accessibility cũ đã hỏng của app, để cấp lại quyền từ đầu
reset-perm:
	@pkill -x $(APP) 2>/dev/null || true
	tccutil reset Accessibility $(BUNDLE_ID)

clean:
	rm -rf build
