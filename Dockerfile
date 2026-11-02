FROM node:24-bookworm-slim AS dependencies
WORKDIR /app
COPY app/package.json app/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM node:24-bookworm-slim AS runtime
ENV NODE_ENV=production PORT=3000
WORKDIR /app
ARG APP_VERSION=1.0.0
ARG COMMIT_SHA=local
ENV APP_VERSION=${APP_VERSION} COMMIT_SHA=${COMMIT_SHA}
LABEL org.opencontainers.image.title="ReleaseLab" org.opencontainers.image.revision="${COMMIT_SHA}"
COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node app/package.json ./
COPY --chown=node:node app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/main.js"]
