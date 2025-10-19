
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app


COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get


COPY . .

ARG BACKEND_URL=/api
RUN flutter build web --release \
    --dart-define=BACKEND_URL=${BACKEND_URL}


FROM nginx:1.25-alpine

COPY --from=build /app/build/web/ /usr/share/nginx/html/


ENV API_UPSTREAM=http://91.132.57.66:8066
ENV NGINX_ENVSUBST_TEMPLATE_DIR=/etc/nginx/templates
COPY docker/default.conf.template /etc/nginx/templates/default.conf.template


RUN printf 'server_tokens off;\n' > /etc/nginx/conf.d/server_tokens.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
