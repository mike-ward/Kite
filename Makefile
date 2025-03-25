.PHONY: all debug prod

all:
	cd src && v -o ../kite run . &
debug:
	cd src &&v -g -o ../kite run . &
prod:
	cd src && v -prod -o ../kite .