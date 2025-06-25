#
# this file is generated via docker-builder/generate.pl
#
# do not edit it directly
#
FROM perl:5.40.2

WORKDIR /usr/src/app
EXPOSE 3000 3001 8080

RUN groupadd --gid 1000 perl \
  && useradd --uid 1000 --gid perl --shell /bin/bash --create-home perl

RUN set -ex \
  && apt-get update && apt-get install -y --no-install-recommends \
    cpanminus \
    software-properties-common \
    dirmngr \
    build-essential \
    libmojolicious-perl \
    libmojolicious-plugin-authentication-perl \
    libclass-dbi-perl \
    libclass-dbi-mysql-perl \
    libdbd-mysql-perl \
    libdigest-perl-md5-perl \
    libcompress-raw-zlib-perl \
    libperlio-gzip-perl \
    libuuid-tiny-perl \
    libanyevent-perl \
    libanyevent-websocket-client-perl \
    libjson-xs-perl \
    libconfig-simple-perl \
    libdigest-bcrypt-perl \
    libhtml-escape-perl \
    libwww-perl \
    libsys-meminfo-perl \
    libnet-http-perl \
  && cpanm \
    Cpanel::JSON::XS \
    CryptX \
    DBI \
    EV \
    Future::AsyncAwait \
    IO::Socket::Socks \
    Net::SSLeay \
    IO::Socket::SSL \
    Net::DNS::Native \
    Role::Tiny \
    SQL::Abstract \
  && rm -r /var/lib/apt/lists/* \
  && rm -r /root/.cpanm

ENV MOJO_VERSION=9.40

RUN cpanm Mojolicious@"$MOJO_VERSION" \
  Mojolicious::Plugin::Database \
  Mojolicious::Plugin::Authentication \
  Mojolicious::Plugin::CSRFProtect \
  Mojo::AsyncAwait \
  Digest::MD5 \
  Compress::Raw::Zlib \
  IO::Compress::Gzip \
  UUID::Tiny \
  AnyEvent \
  AnyEvent::WebSocket::Client \
  JSON::XS \
  Config::Simple \
  Digest::Bcrypt \
  HTML::Escape \
  LWP::Simple \
  Sys::MemInfo \
  Inline::CPP \
  && rm -r /root/.cpanm

RUN git clone https://github.com/existentialcomics/existentialcomics.git
WORKDIR /kungFuChess

USER perl

ARG NOW=not-set
#LABEL org.opencontainers.image.authors="Corey Mohler"
#LABEL org.opencontainers.image.created=$NOW
#LABEL org.opencontainers.image.description="Kung Fu Chess"
#LABEL org.opencontainers.image.documentation=https://github.com/Tekki/docker-mojolicious/blob/master/README.md
#LABEL org.opencontainers.image.licenses=Artistic-2.0
#LABEL org.opencontainers.image.source=https://github.com/Tekki/docker-mojolicious/blob/master/main/Dockerfile
#LABEL org.opencontainers.image.title=KungFuChess
#LABEL org.opencontainers.image.url=https://github.com/Tekki/docker-mojolicious
#LABEL org.opencontainers.image.version=9.40

#CMD ["morbo KungFuWeb.pl -l 'http://localhost:3000' -w templates/ -w KungFuChess/"]
CMD ["/bin/bash", "-c"]
