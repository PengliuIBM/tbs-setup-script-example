###This dockerfile include essential cli tools for jenkins + tbs intergration
FROM jenkinsci/jnlp-slave

USER root
RUN apt-get -y update && \
    apt-get -y install git jq
COPY ./kp /usr/local/bin/
COPY ./kubectl /usr/local/bin/
COPY ./yq /usr/local/bin/
RUN chmod +x /usr/local/bin/kp /usr/local/bin/kubectl /usr/local/bin/yq
WORKDIR /tmp
ENTRYPOINT ["jenkins-slave"]

