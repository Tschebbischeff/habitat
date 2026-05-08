FROM alpine

RUN apk -U add gosu bash git grep docker docker-cli-compose

RUN mkdir -p "/habitat-deploy"
COPY ./entrypoint.sh /habitat-deploy/entrypoint.sh
RUN chmod +x "/habitat-deploy/entrypoint.sh"
COPY ./deploy.sh /habitat-deploy/deploy.sh
RUN chmod +x "/habitat-deploy/deploy.sh"

WORKDIR /habitat-deploy
ENTRYPOINT [ "/habitat-deploy/entrypoint.sh" ]
CMD [ "/habitat-deploy/deploy.sh" ]