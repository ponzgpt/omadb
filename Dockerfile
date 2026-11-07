# Production image. Built on hoid by scripts/deploy.sh.
FROM ruby:4.0.9-slim AS base
WORKDIR /rails
ENV RAILS_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_PATH=/usr/local/bundle BUNDLE_WITHOUT="development:test"
RUN apt-get update -qq && apt-get install -y --no-install-recommends curl libsqlite3-0 libyaml-0-2 && rm -rf /var/lib/apt/lists/*

FROM base AS build
RUN apt-get update -qq && apt-get install -y --no-install-recommends build-essential git libyaml-dev pkg-config && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && rm -rf ~/.bundle "$BUNDLE_PATH"/ruby/*/cache && bundle exec bootsnap precompile --gemfile
COPY . .
RUN bundle exec bootsnap precompile app/ lib/ && SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile

FROM base
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
RUN useradd rails --create-home --shell /bin/bash && mkdir -p storage log tmp && chown -R rails:rails storage log tmp
USER rails
EXPOSE 80
CMD ["bash", "-c", "bin/rails db:prepare && exec bin/thrust bin/rails server"]
