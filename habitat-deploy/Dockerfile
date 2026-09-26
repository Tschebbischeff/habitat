FROM alpine

RUN apk -U add gosu bash git grep docker docker-cli-compose docker-cli-buildx

RUN mkdir -p /habitat-deploy

COPY ./entrypoint.sh /habitat-deploy/entrypoint.sh
RUN chmod +x "/habitat-deploy/entrypoint.sh"
COPY ./healthcheck.sh /habitat-deploy/healthcheck.sh
RUN chmod +x "/habitat-deploy/healthcheck.sh"
COPY ./bin /habitat-deploy/bin
RUN find "/habitat-deploy/bin" -type f -exec chmod +x {} \;
ENV PATH="/habitat-deploy/bin:$PATH"

WORKDIR /habitat-deploy
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "supervisor" ]