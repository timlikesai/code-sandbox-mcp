FROM ruby:3.4.4-alpine AS base

RUN apk add --no-cache \
    build-base \
    curl \
    git \
    python3 \
    nodejs \
    npm \
    zsh \
    fish \
    bash \
    shadow \
    && npm install -g tsx

WORKDIR /app

COPY Gemfile Gemfile.lock* ./

FROM base AS builder
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle config set --local path 'vendor/bundle' && \
    bundle install --jobs 4 --retry 3

FROM base AS production
# Copy only production gems from builder
COPY --from=builder /app/vendor/bundle /app/vendor/bundle

# Copy only production files (exclude dev/test files)
COPY lib/ ./lib/
COPY bin/ ./bin/
COPY Gemfile Gemfile.lock* ./
COPY docker-entrypoint.sh /usr/local/bin/

# Configure bundler and setup user in single layer
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle config set --local path 'vendor/bundle' && \
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    useradd -m -s /bin/bash sandbox && \
    chown -R sandbox:sandbox /app

USER sandbox

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []

FROM builder AS test
USER root

# Install development and test gems
RUN bundle config unset --local without && \
    bundle install --jobs 4 --retry 3

# Copy all files including test/dev files
COPY . .

# Create test directories and setup user
RUN mkdir -p /app/coverage /app/tmp && \
    useradd -m -s /bin/bash sandbox && \
    chown -R sandbox:sandbox /app

USER sandbox
WORKDIR /app