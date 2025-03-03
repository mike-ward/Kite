.PHONY: all

all:
	v run . &
debug:
	v -g run . &
prod:
	v -prod .