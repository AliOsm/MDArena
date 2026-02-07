# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t md_arena .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name md_arena md_arena

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.7
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages (libgit2 runtime needed for Rugged gem)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libgit2-1.9 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems and node modules (cmake + libgit2-dev for Rugged)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential cmake git libgit2-dev libpq-dev libyaml-dev node-gyp pkg-config python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install JavaScript dependencies
ARG NODE_VERSION=25.2.1
ARG YARN_VERSION=4.12.0
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    rm -rf /tmp/node-build-master
RUN corepack enable && yarn set version $YARN_VERSION

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Install node modules
COPY package.json yarn.lock .yarnrc.yml ./
RUN yarn install --immutable

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


RUN rm -rf node_modules


# Final stage for app image
FROM base

# Install nginx, git, and fcgiwrap for serving git over HTTP
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y nginx git fcgiwrap spawn-fcgi && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p /tmp/nginx/client_body /tmp/nginx/proxy /tmp/nginx/fastcgi /tmp/nginx/uwsgi /tmp/nginx/scgi && \
    chown -R rails:rails /tmp/nginx /var/log/nginx

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Copy production nginx config
RUN cp /rails/config/nginx/nginx.conf /etc/nginx/nginx.conf

USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start nginx + puma + fcgiwrap via start-server
EXPOSE 80
CMD ["./bin/start-server"]
