FROM ruby:3.4.4-slim AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    python3 \
    nodejs \
    npm \
    zsh \
    fish \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g tsx

WORKDIR /app

COPY Gemfile Gemfile.lock* ./

# Production stage - minimal dependencies
FROM base AS production
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

COPY . .

# Copy and set up entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN useradd -m -s /bin/bash sandbox && \
    chown -R sandbox:sandbox /app

USER sandbox

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []

# Test stage - extends production with dev dependencies
FROM production AS test
USER root

# Install all dependencies including dev/test
RUN bundle config unset --local without && \
    bundle install

USER sandbox