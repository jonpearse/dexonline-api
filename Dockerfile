FROM ruby:3.2

WORKDIR /dexonline-api

# Install Gems (separately, so as to avoid updating layers too much)
COPY Gemfile* .
RUN bundle install

# Copy everything else (except the tmp directory)
COPY . .

# expose port 3000 + start puma
EXPOSE 3000
ENTRYPOINT [ "bundle", "exec", "puma", "-p", "3000" ]
