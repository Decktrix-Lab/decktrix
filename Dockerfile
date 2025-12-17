FROM ubuntu:noble

RUN apt-get update

RUN	apt-get install -y \
		sudo \
		wget \
		bc \
		bison \
		build-essential \
		flex \
		libgnutls28-dev \
		libssl-dev \
		python3-dev \
		python3-minimal \
		python3-setuptools \
		swig \
		uuid-dev \
		build-essential \
		python3-cryptography \
		python3-pyelftools \
		build-essential \
		device-tree-compiler \
		dosfstools \
		genimage \
		mtools \
