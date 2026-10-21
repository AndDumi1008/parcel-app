# Web deploy account for one environment (AI-Gov-Layer PD-44/PD-45): sshd with a forced command that can only
# deploy, roll back or report the release served from this environment's web volume. GNU coreutils, tar and
# findutils instead of the busybox applets: `mv -T` (atomic link switch) and `tar -P` (raw member names).
FROM alpine:3.20
RUN apk add --no-cache openssh-server coreutils tar findutils \
 && adduser -D -H -h /srv -s /bin/sh deploy \
 && echo 'deploy:*' | chpasswd -e \
 && mkdir -p /keys /run
COPY sshd_config /etc/ssh/sshd_config
COPY web-deploy-shell entrypoint.sh /usr/local/bin/
EXPOSE 2222
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
