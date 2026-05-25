ifeq ($(GNUSTEP_MAKEFILES),)
include Makefile
else
include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = StepDown
StepDown_OBJC_FILES = src/main.m src/AppDelegate.m src/MarkdownRenderer.m
StepDown_RESOURCE_FILES = resources/Info-gnustep.plist resources/StepDown.png resources/StepDown.svg resources/StepDown.tiff
StepDown_APPLICATION_ICON = StepDown.tiff
ADDITIONAL_OBJCFLAGS = -std=gnu99 -Wall -Wextra

include $(GNUSTEP_MAKEFILES)/application.make
endif
