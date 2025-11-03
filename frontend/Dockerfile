# Build frontend with Vite
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

ARG VITE_CATALOG_API="/api"
ARG VITE_CART_API="/api"
ARG VITE_ORDER_API="/api"
ENV VITE_CATALOG_API=${VITE_CATALOG_API} \
    VITE_CART_API=${VITE_CART_API} \
    VITE_ORDER_API=${VITE_ORDER_API} \
    NODE_ENV=production

RUN npm run build

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK CMD wget --no-verbose --tries=1 --spider http://127.0.0.1/healthz || exit 1
