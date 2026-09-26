FROM alpine

RUN apk -U add gosu bash git grep docker docker-cli-compose docker-cli-buildx

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x "/entrypoint.sh"
COPY ./healthcheck.sh /healthcheck.sh
RUN chmod +x "/healthcheck.sh"
COPY ./bin /habitat-deploy
RUN find "/habitat-deploy" -type f -exec chmod +x {} \;
ENV PATH="/habitat-deploy:$PATH"

WORKDIR /habitat-deploy
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "deploy" ]