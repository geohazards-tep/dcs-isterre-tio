# This Makefile is here to ease things for people not used to maven commands

.PHONY: install clean

install: clean
	mvn install

clean:
	mvn clean
