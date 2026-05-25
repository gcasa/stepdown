APP_NAME = StepDown
SRC = src/main.m src/AppDelegate.m src/MarkdownRenderer.m
RESOURCES = resources/StepDown.png resources/StepDown.tiff resources/StepDown.svg

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
BUILD_DIR = build
APP_DIR = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources
BIN = $(MACOS_DIR)/$(APP_NAME)
OBJCFLAGS = -std=gnu99 -Wall -Wextra -Wno-unused-parameter -fno-objc-arc
LDFLAGS = -framework Cocoa

.PHONY: all clean run

all: $(APP_DIR)

$(APP_DIR): $(BIN) resources/Info.plist
	mkdir -p $(RESOURCES_DIR)
	cp resources/Info.plist $(CONTENTS_DIR)/Info.plist
	cp $(RESOURCES) $(RESOURCES_DIR)/

$(BIN): $(SRC)
	mkdir -p $(MACOS_DIR)
	clang $(OBJCFLAGS) -o $@ $(SRC) $(LDFLAGS)

run: all
	open $(APP_DIR)

clean:
	rm -rf $(BUILD_DIR)
else
GNUSTEP_CONFIG := $(shell command -v gnustep-config 2>/dev/null)
OBJC = clang
OBJCFLAGS = -std=gnu99 -Wall -Wextra -fconstant-string-class=NSConstantString $(shell gnustep-config --objc-flags)
LDFLAGS = $(shell gnustep-config --gui-libs)
OBJ_DIR = obj
OBJ = $(SRC:src/%.m=$(OBJ_DIR)/%.o)
BIN = $(OBJ_DIR)/$(APP_NAME)

.PHONY: all clean run

all: $(BIN)

$(BIN): $(OBJ) $(RESOURCES)
	$(OBJC) -o $@ $(OBJ) $(LDFLAGS)

$(OBJ_DIR)/%.o: src/%.m
	mkdir -p $(OBJ_DIR)
	$(OBJC) $(OBJCFLAGS) -c $< -o $@

run: all
	./$(BIN)

clean:
	rm -rf $(OBJ_DIR) $(APP_NAME).app
endif
