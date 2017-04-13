# This Makefile is here to ease things for people not used to maven commands

.PHONY: install clean fetch-rpm-src

install: clean
	mvn install

clean:
	mvn clean

fetch-rpm-srcs:
	mkdir -p rpmbuild/SOURCES
	cd rpmbuild/SOURCES; curl -O ftp://ist-ftp.ujf-grenoble.fr/users/volatm/nsbas_invers_optic-0.1853.tar.bz2
	cd rpmbuild/SOURCES; curl -L -omicmac-fbf9dedc4c23e026a3ff780f408395d07b14d92e.zip https://github.com/micmacIGN/micmac/archive/fbf9dedc4c23e026a3ff780f408395d07b14d92e.zip
