FROM ubuntu:24.04 AS compilacion
RUN apt-get update && apt-get install -y --no-install-recommends gnat \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY *.ads *.adb ./
RUN gnatmake -gnat2012 -gnatwa -gnatwU -gnatwe -gnato coordinador.adb \
    && gnatmake -gnat2012 -gnatwa -gnatwU -gnatwe -gnato barco.adb

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends libgnat-13 redis-tools \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=compilacion /src/barco /src/coordinador ./
CMD ["/app/coordinador"]
