# Etapa 1: compilar (necesita el compilador de Ada)
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends gnat && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY *.ads *.adb ./
RUN gnatmake -O2 puerto.adb && gnatmake -O2 barco.adb

# Etapa 2: imagen final liviana, solo con la libreria de ejecucion de Ada y los dos binarios
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends libgnat-12 && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/puerto /src/barco /usr/local/bin/
CMD ["puerto"]
