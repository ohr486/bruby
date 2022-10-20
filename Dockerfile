FROM erlang:25.1

RUN mkdir /buildroot
WORKDIR /buildroot

COPY Makefile /buildroot
COPY bin/ /buildroot/bin
COPY lib/ /buildroot/lib
