.PHONY: test test-file lint clean

# Default plenary location (can be overridden)
PLENARY_PATH ?= $(HOME)/.local/share/nvim/lazy/plenary.nvim

# Check if plenary exists, if not try to clone it
ensure-plenary:
	@if [ ! -d "$(PLENARY_PATH)" ] && [ ! -d "/tmp/plenary.nvim" ]; then \
		echo "Cloning plenary.nvim to /tmp/plenary.nvim..."; \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim /tmp/plenary.nvim; \
	fi

# Run all tests
test: ensure-plenary
	@echo "Running tests..."
	@PLENARY_PATH=$(PLENARY_PATH) nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

# Run a specific test file (usage: make test-file FILE=tests/config_spec.lua)
test-file: ensure-plenary
	@echo "Running $(FILE)..."
	@PLENARY_PATH=$(PLENARY_PATH) nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)"

# Run tests with verbose output
test-verbose: ensure-plenary
	@echo "Running tests (verbose)..."
	@PLENARY_PATH=$(PLENARY_PATH) nvim --headless -u tests/minimal_init.lua \
		-c "lua require('plenary.test_harness').test_directory('tests/', {minimal_init = 'tests/minimal_init.lua', sequential = true})"

# Lint with luacheck (if installed)
lint:
	@if command -v luacheck > /dev/null 2>&1; then \
		luacheck lua/ --globals vim jit; \
	else \
		echo "luacheck not installed, skipping lint"; \
	fi

# Clean temporary files
clean:
	@rm -rf /tmp/plenary.nvim
	@echo "Cleaned temporary files"

# Help
help:
	@echo "Available targets:"
	@echo "  test         - Run all tests"
	@echo "  test-file    - Run specific test (FILE=tests/xxx_spec.lua)"
	@echo "  test-verbose - Run tests with verbose output"
	@echo "  lint         - Run luacheck linter"
	@echo "  clean        - Remove temporary files"
	@echo "  help         - Show this help"
