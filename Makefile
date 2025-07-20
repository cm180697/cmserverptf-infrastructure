# Makefile
SHELL := /bin/bash

.PHONY: help install lint test check

help:
	@echo "Available commands:"
	@echo "  install   : Install all project dependencies using Poetry."
	@echo "  lint      : Run pre-commit checks (black, flake8) on all files."
	@echo "  test      : Run all unit tests with pytest."
	@echo "  check     : Run both linting and testing checks."

install:
	@echo "--- Installing dependencies ---"
	poetry install --with dev

lint:
	@echo "--- Running linters ---"
	poetry run pre-commit run --all-files

test:
	@echo "--- Running unit tests ---"
	poetry run pytest

check: install lint test
	@echo "--- All checks passed successfully! ---"