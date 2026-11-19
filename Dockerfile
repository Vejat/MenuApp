FROM debian:bookworm-slim AS web-build
ARG FLUTTER_VERSION=3.47.5
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils && rm -rf /var/lib/apt/lists/*
RUN git clone --branch "${FLUTTER_VERSION}" --depth 1 https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}" CI=true FLUTTER_SUPPRESS_ANALYTICS=true
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY lib/ lib/
COPY web/ web/
RUN flutter build web --no-pub --no-wasm-dry-run --dart-define=API_URL=

FROM node:24-bookworm-slim
WORKDIR /app/api
ENV NODE_ENV=production WEB_ROOT=/app/web API_HOST=0.0.0.0 PORT=10000
COPY api/package.json api/package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY api/ ./
COPY --from=web-build /src/build/web/ /app/web/
USER node
EXPOSE 10000
CMD ["node", "server.mjs"]
