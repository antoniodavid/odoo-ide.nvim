NVIM ?= nvim

.PHONY: test test-context test-doodba test-odools test-smoke

test:
	@for file in tests/test_*.lua; do \
		echo "==> $$file"; \
		$(NVIM) --headless -u NONE -l "$$file" || exit 1; \
	done

test-context:
	@$(NVIM) --headless -u NONE -l tests/test_context.lua

test-doodba:
	@$(NVIM) --headless -u NONE -l tests/test_doodba_root.lua

test-odools:
	@$(NVIM) --headless -u NONE -l tests/test_odools_config.lua

test-smoke:
	@$(NVIM) --headless -u NONE -l tests/test_nvim.lua
