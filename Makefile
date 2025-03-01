.PHONY: all

all:
	v run . &

prod:
	v -gc boehm_full_opt -prod .