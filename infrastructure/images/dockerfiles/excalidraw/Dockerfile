FROM node:24 AS build

WORKDIR /opt/node_app

COPY . .

RUN --mount=type=cache,target=/root/.cache/yarn \
    yarn --network-timeout 600000

ARG NODE_ENV=production

RUN yarn build:app:docker

FROM nginx:1.27-alpine

RUN apk upgrade --no-cache

COPY --from=build /opt/node_app/excalidraw-app/build /usr/share/nginx/html

HEALTHCHECK CMD wget -q -O /dev/null http://localhost || exit 1
