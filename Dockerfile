FROM ruby:3.4

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
RUN chmod +x bin/docker-entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["bin/docker-entrypoint.sh"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]