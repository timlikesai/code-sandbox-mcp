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
    jq \
    openjdk21-jdk \
    clojure \
    && npm install -g tsx \
    && mkdir -p /opt/jvm-languages \
    && cd /opt/jvm-languages \
    && curl -L https://github.com/JetBrains/kotlin/releases/download/v1.9.22/kotlin-compiler-1.9.22.zip -o kotlin.zip \
    && unzip kotlin.zip && rm kotlin.zip \
    && curl -L https://groovy.jfrog.io/artifactory/dist-release-local/groovy-zips/apache-groovy-binary-4.0.18.zip -o groovy.zip \
    && unzip groovy.zip && rm groovy.zip \
    && mv groovy-4.0.18 groovy \
    && curl -L https://github.com/lampepfl/dotty/releases/download/3.3.1/scala3-3.3.1.tar.gz -o scala.tar.gz \
    && tar xzf scala.tar.gz && rm scala.tar.gz \
    && mv scala3-3.3.1 scala \
    && ln -s /opt/jvm-languages/kotlinc/bin/kotlin /usr/local/bin/kotlin \
    && ln -s /opt/jvm-languages/kotlinc/bin/kotlinc /usr/local/bin/kotlinc \
    && ln -s /opt/jvm-languages/groovy/bin/groovy /usr/local/bin/groovy \
    && ln -s /opt/jvm-languages/scala/bin/scala /usr/local/bin/scala \
    && ln -s /opt/jvm-languages/scala/bin/scalac /usr/local/bin/scalac

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