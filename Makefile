FLUTTER ?= flutter

# Run before every build: static analysis + unit tests.
check:
	$(FLUTTER) analyze
	$(FLUTTER) test

run:
	$(FLUTTER) run -d macos --dart-define-from-file=.env.development

build-windows: check
	$(FLUTTER) build windows --release --dart-define-from-file=.env.production

build-macos: check
	$(FLUTTER) build macos --release --dart-define-from-file=.env.production

.PHONY: check run build-windows build-macos
