FROM instrumentisto/flutter:3.27 AS build
WORKDIR /app
# Default = API di produzione (vedi ApiConstants.baseUrl); docker-compose.dev.yml
# lo sovrascrive per puntare al backend locale.
ARG API_BASE_URL=https://incampo-api.studiorocket.it
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
# --pwa-strategy=none: il service worker di Flutter litigherebbe con push-sw.js
# (due worker sullo stesso scope si disinstallano a vicenda e la subscription push muore).
RUN flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=$API_BASE_URL

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
