FROM alpine:3.22 AS downloader
RUN apk add --no-cache curl unzip tar
WORKDIR /downloads

RUN curl -L https://github.com/JetBrains/kotlin/releases/download/v1.9.22/kotlin-compiler-1.9.22.zip -o kotlin.zip \
    && unzip -q kotlin.zip && rm kotlin.zip \
    && curl -L https://groovy.jfrog.io/artifactory/dist-release-local/groovy-zips/apache-groovy-binary-4.0.18.zip -o groovy.zip \
    && unzip -q groovy.zip && rm groovy.zip \
    && mv groovy-4.0.18 groovy \
    && curl -L https://github.com/lampepfl/dotty/releases/download/3.3.1/scala3-3.3.1.tar.gz -o scala.tar.gz \
    && tar xzf scala.tar.gz && rm scala.tar.gz \
    && mv scala3-3.3.1 scala

RUN find kotlinc \( -name "*.txt" -o -name "*.md" -o -name "*.html" -o -name "LICENSE*" -o -name "NOTICE*" \) -delete \
    && rm -rf kotlinc/license kotlinc/lib/kotlin-test* kotlinc/lib/kotlin-annotation* \
    && find groovy \( -name "*.txt" -o -name "*.html" -o -name "LICENSE*" -o -name "NOTICE*" \) -delete \
    && rm -rf groovy/licenses groovy/grooid groovy/lib/*groovydoc*.jar groovy/lib/*javadoc*.jar \
    && rm -rf groovy/lib/groovy-test*.jar groovy/lib/groovy-testng*.jar groovy/lib/junit*.jar groovy/lib/testng*.jar \
    && find scala \( -name "*.txt" -o -name "*.md" -o -name "*.html" -o -name "LICENSE*" -o -name "NOTICE*" \) -delete \
    && rm -rf scala/doc scala/api scala/lib/*-sources.jar && \
    strip --strip-unneeded kotlinc/bin/* groovy/bin/* scala/bin/* 2>/dev/null || true

FROM ruby:3.4.5-alpine AS base

RUN apk add --no-cache \
    python3 \
    nodejs \
    npm \
    bash \
    jq \
    openjdk21-jdk \
    clojure \
    zsh \
    fish \
    && npm install -g tsx --no-fund --no-audit \
    && rm -rf /var/cache/apk/* /root/.npm \
    && rm -rf /usr/lib/jvm/java-21-openjdk/jmods \
    && rm -rf /usr/lib/jvm/java-21-openjdk/src.zip \
    && rm -rf /usr/lib/jvm/java-21-openjdk/lib/src.zip

COPY --from=downloader /downloads/kotlinc /opt/jvm-languages/kotlinc
COPY --from=downloader /downloads/groovy /opt/jvm-languages/groovy
COPY --from=downloader /downloads/scala /opt/jvm-languages/scala

RUN ln -s /opt/jvm-languages/kotlinc/bin/kotlin /usr/local/bin/kotlin \
    && ln -s /opt/jvm-languages/kotlinc/bin/kotlinc /usr/local/bin/kotlinc \
    && ln -s /opt/jvm-languages/groovy/bin/groovy /usr/local/bin/groovy \
    && ln -s /opt/jvm-languages/scala/bin/scala /usr/local/bin/scala \
    && ln -s /opt/jvm-languages/scala/bin/scalac /usr/local/bin/scalac

WORKDIR /app

COPY Gemfile Gemfile.lock* ./

FROM base AS builder
RUN apk add --no-cache build-base git \
    && bundle config set --local deployment 'true' \
    && bundle config set --local without 'development test' \
    && bundle config set --local path 'vendor/bundle' \
    && bundle install --jobs 4 --retry 3 \
    && rm -rf /var/cache/apk/* \
    && find vendor/bundle -name "*.o" -delete \
    && find vendor/bundle -name "*.c" -delete

FROM base AS production
COPY --from=builder /app/vendor/bundle /app/vendor/bundle

COPY lib/ ./lib/
COPY bin/ ./bin/
COPY Gemfile Gemfile.lock* ./
COPY docker-entrypoint.sh /usr/local/bin/

RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle config set --local path 'vendor/bundle' && \
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    adduser -D -s /bin/sh -h /home/sandbox -g "" sandbox && \
    chown -R sandbox:sandbox /app && \
    rm -rf /tmp/* /var/tmp/* && \
    find /usr/lib/python*/site-packages -name "*.pyc" -delete && \
    find /usr/lib/python*/site-packages -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

USER sandbox

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []

FROM builder AS test
USER root

RUN apk add --no-cache build-base git \
    && bundle config unset --local without \
    && bundle install --jobs 4 --retry 3 \
    && rm -rf /var/cache/apk/*

COPY lib/ ./lib/
COPY spec/ ./spec/
COPY examples/ ./examples/
COPY Rakefile ./
COPY .rspec ./
COPY .rubocop.yml ./
COPY *.md ./

RUN mkdir -p /app/coverage /app/tmp && \
    adduser -D -s /bin/sh -h /home/sandbox -g "" sandbox && \
    chown -R sandbox:sandbox /app

USER sandbox
WORKDIR /app