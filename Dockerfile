FROM ruby:2.5.3-alpine3.8

ADD . /knative-assistant-router
WORKDIR /knative-assistant-router

RUN bundle install

ENTRYPOINT ["bundle", "exec", "ruby", "server.rb"]