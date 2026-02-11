FROM ruby:4.0.1-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY app/Gemfile app/Gemfile.lock* ./

RUN bundle install

COPY app/ ./

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
