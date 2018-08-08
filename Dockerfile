FROM ubuntu:16.04 as base

ENV DEBIAN_FRONTEND=noninteractive TERM=xterm
RUN echo "export > /etc/envvars" >> /root/.bashrc && \
    echo "export PS1='\[\e[1;31m\]\u@\h:\w\\$\[\e[0m\] '" | tee -a /root/.bashrc /etc/skel/.bashrc && \
    echo "alias tcurrent='tail /var/log/*/current -f'" | tee -a /root/.bashrc /etc/skel/.bashrc

RUN apt-get update
RUN apt-get install -y locales && locale-gen en_US.UTF-8 && dpkg-reconfigure locales
ENV LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

# Runit
RUN apt-get install -y --no-install-recommends runit
CMD bash -c 'export > /etc/envvars && /usr/sbin/runsvdir-start'

# Utilities
RUN apt-get install -y --no-install-recommends vim less net-tools inetutils-ping wget curl git telnet nmap socat dnsutils netcat tree htop unzip sudo software-properties-common jq psmisc iproute python ssh rsync gettext-base

#Install Oracle Java 8
RUN add-apt-repository ppa:webupd8team/java -y && \
    apt-get update && \
    echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections && \
    apt-get install -y oracle-java8-installer && \
    apt install oracle-java8-unlimited-jce-policy && \
    rm -r /var/cache/oracle-jdk8-installer
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

RUN wget https://downloads.gradle.org/distributions/gradle-4.9-bin.zip && \
    unzip gradle*.zip && \
    rm gradle*.zip
RUN ln -s /gradle-*/bin/gradle /usr/local/bin/gradle

# Build Stage
FROM base as build

# Setup ssh key, docker build --build-arg SSH_KEY="$(cat id_rsa)" ...
ARG SSH_KEY
RUN if [ "$SSH_KEY" ]; then  \
      mkdir -p /root/.ssh && \
      chmod 0700 /root/.ssh && \
      ssh-keyscan github.com > /root/.ssh/known_hosts && \
      echo "${SSH_KEY}" > /root/.ssh/id_rsa && \
      chmod 600 /root/.ssh/id_rsa \
    ;fi

COPY app /app
RUN cd /app && \
    gradle build

# Final Stage
FROM base as final
COPY --from=build /app /app

# Add runit services
COPY sv /etc/service 
ARG BUILD_INFO
LABEL BUILD_INFO=$BUILD_INFO
