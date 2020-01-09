FROM golang:1.13

COPY cmd/freegeoip/public /var/www

ADD . /go/src/github.com/apilayer/freegeoip
RUN \
	cd /go/src/github.com/apilayer/freegeoip/cmd/freegeoip && \
	go mod download && go get -d && go install && \
	apt-get update && apt-get install -y libcap2-bin && \
	setcap cap_net_bind_service=+ep /go/bin/freegeoip && \
	apt-get clean && rm -rf /var/lib/apt/lists/* && \
	useradd -ms /bin/bash freegeoip

ARG INITIAL_DATABASE_URL
ENV INITIAL_DATABASE_URL=${INITIAL_DATABASE_URL}

USER freegeoip
ENTRYPOINT ["/go/bin/freegeoip"]

EXPOSE 8080

ENV QUOTA_MAX=0

# CMD instructions:
# Add  "-use-x-forwarded-for"      if your server is behind a reverse proxy
# Add  "-public", "/var/www"       to enable the web front-end
# Add  "-internal-server", "8888"  to enable the pprof+metrics server
#
# Example:
# CMD ["-use-x-forwarded-for", "-public", "/var/www", "-internal-server", "8888"]
