ARG PYTHON_BASE_IMAGE=2.7-slim-buster

FROM buildpack-deps:curl AS ffmpeg
RUN apt-get update && apt-get install -y xz-utils
RUN echo "$(dpkg --print-architecture)"
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
  amd64) ARCH='amd64';; \
  arm64) ARCH='arm64';; \
  armhf) ARCH='armhf';; \
  *) echo "unsupported architecture: $(dpkg --print-architecture)"; exit 1 ;; \
  esac \
  && set -ex \
  && curl -fsSLO "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-$ARCH-static.tar.xz" \
  && mkdir -p /opt \
  && tar -xJf "ffmpeg-release-$ARCH-static.tar.xz" --strip-components=1 -C /opt

FROM python:${PYTHON_BASE_IMAGE} AS cura-compiler

ARG CURA_VERSION
ENV CURA_VERSION ${CURA_VERSION:-15.04.6}

RUN apt-get update && apt-get install -y g++ make curl
RUN curl -fsSLO --compressed --retry 3 --retry-delay 10 \
  https://github.com/Ultimaker/CuraEngine/archive/${CURA_VERSION}.tar.gz \
  && mkdir -p /opt \
  && tar -xzf ${CURA_VERSION}.tar.gz --strip-components=1 -C /opt --no-same-owner
WORKDIR /opt
RUN make

# build ocotprint
FROM python:${PYTHON_BASE_IMAGE} AS compiler

ARG tag
ENV tag ${tag:-master}

RUN apt-get update && apt-get install -y build-essential curl

RUN	curl -fsSLO --compressed --retry 3 --retry-delay 10 \
  https://github.com/OctoPrint/OctoPrint/archive/${tag}.tar.gz \
	&& mkdir -p /opt/venv \
  && tar xzf ${tag}.tar.gz --strip-components 1 -C /opt/venv --no-same-owner

#install venv            
RUN pip install virtualenv
RUN python -m virtualenv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
WORKDIR /opt/venv
RUN python setup.py install

#install slic3r plugin
RUN echo "Installing Slic3r plugin..."
RUN pip install https://github.com/javierma/OctoPrint-Slic3r/archive/master.zip

# Install Slic3r Base 
ARG SLIC3R_VERSION=1.3.0

RUN echo "The installation of Slic3r takes a long time. PLease be patient"
RUN echo "Installing libraries and dependencies required by Slic3r..."
RUN apt-get install --yes --no-install-recommends \
    libboost-all-dev \
    libboost-geometry-utils-perl \
    libboost-system-dev \
    libboost-thread-dev \
    libgtk2.0-dev \
    libwxgtk3.0-0v5 \
    libwx-perl \
    libmodule-build-perl \
    libnet-dbus-perl \
    cpanminus \
    libextutils-cbuilder-perl \
    libwx-perl \
    libperl-dev \
    unzip \
    libxml-sax-expatxs-perl \
    libclass-xsaccessor-perl

RUN apt-get clean \
	&& rm -rf /tmp/* /var/tmp/*  \
    && rm -rf /var/lib/apt/lists/*


WORKDIR /
RUN curl -fsSLO --compressed --retry 3 --retry-delay 10 https://github.com/slic3r/Slic3r/archive/master.zip 
RUN mkdir /Slic3r \
	&& unzip master.zip -d /Slic3r/
RUN perl /Slic3r/Slic3r-master/Build.PL
#sudo perl Build.PL


FROM python:${PYTHON_BASE_IMAGE} AS build
LABEL description="The snappy web interface for your 3D printer"
LABEL authors="longlivechief <chief@hackerhappyhour.com>, badsmoke <dockerhub@badcloud.eu>"
LABEL issues="github.com/OcotPrint/docker/issues"

RUN apt-get update && apt-get install -y build-essential

RUN groupadd --gid 1000 octoprint \
  && useradd --uid 1000 --gid octoprint -G dialout --shell /bin/bash --create-home octoprint

#Install Octoprint, ffmpeg, and cura engine
COPY --from=compiler /opt/venv /opt/venv
COPY --from=ffmpeg /opt /opt/ffmpeg
COPY --from=cura-compiler /opt/build /opt/cura

RUN chown -R octoprint:octoprint /opt/venv
ENV PATH="/opt/venv/bin:/opt/ffmpeg:/opt/cura:$PATH"

EXPOSE 5000
COPY docker-entrypoint.sh /usr/local/bin/
USER octoprint
VOLUME /home/octoprint
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["octoprint", "serve"]
