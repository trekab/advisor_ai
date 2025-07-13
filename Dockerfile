FROM ruby:3.3

# Replace with your desired Node version
ENV NODE_VERSION=18.18.0
ENV BUNDLER_VERSION=2.5.5

# Install dependencies
RUN apt-get update -qq && \
  apt-get install -y build-essential libpq-dev nodejs npm curl && \
  npm install -g yarn

# Set up app directory
WORKDIR /app

# Copy Gemfiles and install gems
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v $BUNDLER_VERSION
RUN bundle install

# Copy the rest of the app
COPY . .

# Precompile assets if needed
# RUN bundle exec rake assets:precompile

CMD ["bin/dev"]
