FROM ubuntu:noble

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
		sudo \
		wget \
		curl \
		ca-certificates \
		git \
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
		python3-cryptography \
		python3-pyelftools \
		device-tree-compiler \
		dosfstools \
		genimage \
		mtools \
		debootstrap \
		qemu-user-static \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY build-image.sh .
RUN chmod +x build-image.sh

ENTRYPOINT ["./build-image.sh"]
