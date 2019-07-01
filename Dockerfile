# Use the standard Nginx image from Docker Hub
FROM centos/nginx-112-centos7

ENV HOME=/opt/repo

USER root 
# install python, uwsgi, and supervisord
#RUN yum update #&& yum install -y --setopt=tsflags=nodocs supervisor #uwsgi python python-pip #procps vim && \
    #/usr/bin/pip install uwsgi==2.0.17 flask==1.0.2

#RUN  yum install -y  supervisor
     # uwsgi python  procps vim 
     #pip install uwsgi==2.0.17 flask==1.0.2


RUN yum install -y \
        yum-utils \
        curl \
        git \
        rlwrap \
        screen \
        vim \
        emacs-nox && \
    yum install -y \
        epel-release && \
    yum groupinstall -y "Development Tools" && \
    yum install -y \
        cairo-devel \
        libffi-devel \
        libxml2-devel \
        libxslt-devel \
        procps \
        uwsgi

RUN yum clean -y all

# install nodejs version 10
RUN curl -sL https://rpm.nodesource.com/setup_10.x | bash - && \
    yum install -y nodejs

# install and set python3.6 as default
RUN yum install -y centos-release-scl && \
    yum install -y rh-python36
RUN echo '#!/bin/bash' >> /etc/profile.d/enablepython36.sh && \
    echo '. scl_source enable rh-python36' >> /etc/profile.d/enablepython36.sh
ENV BASH_ENV=/etc/profile.d/enablepython36.sh

RUN chmod -R g=u /etc/profile.d/enablepython36.sh /opt/rh/rh-python36 && \
    chgrp -R 0 /etc/profile.d/enablepython36.sh /opt/rh/rh-python36
SHELL ["/bin/bash", "-c"]
RUN pip --version && pip install --upgrade pip pipenv setuptools wheel supervisor  uwsgi==2.0.17 flask==1.0.2


# set the locale
RUN localedef --quiet -c -i en_US -f UTF-8 en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Source code file
COPY ./src ${HOME}/src

# Copy the configuration file from the current directory and paste 
# it inside the container to use it as Nginx's default config.
COPY ./deployment/nginx.conf /etc/nginx.d/nginx.conf

# setup NGINX config
RUN mkdir -p /spool/nginx /run/pid /var/cache/nginx && \
    chmod -R 777 /var/log/nginx /var/cache/nginx /etc/nginx.d /var/run /run /run/pid /spool/nginx && \
    chgrp -R 0 /var/log/nginx /var/cache/nginx /etc/nginx.d /var/run /run /run/pid /spool/nginx && \
    chmod -R g+rwX /var/log/nginx /var/cache/nginx /etc/nginx.d /var/run /run /run/pid /spool/nginx
    #rm /etc/nginx/conf.d/default.conf

# Copy the base uWSGI ini file to enable default dynamic uwsgi process number
COPY ./deployment/uwsgi.ini /etc/uwsgi/apps-available/uwsgi.ini
RUN mkdir -p /etc/uwsgi/apps-enabled/ && \  
    ln -s /etc/uwsgi/apps-available/uwsgi.ini /etc/uwsgi/apps-enabled/uwsgi.ini && \
    mkdir -p /etc/supervisor/conf.d && \
    echo_supervisord_conf > /etc/supervisor/supervisord.conf


COPY ./deployment/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN mkdir -p /var/log/supervisor && \  
   touch /var/log/supervisor/supervisord.log

EXPOSE 8080:8080

# setup entrypoint
COPY ./deployment/entrypoint.sh /usr/local/bin/entrypoint.sh

# access to /dev/stdout
# https://github.com/moby/moby/issues/31243#issuecomment-406879017
RUN ln -s /usr/local/bin/docker-entrypoint.sh / && \
    chmod 777 /usr/local/bin/entrypoint.sh && \
    chgrp -R 0 /usr/local/bin/entrypoint.sh && \
    chown -R nginx:root /usr/local/bin/entrypoint.sh

# https://docs.openshift.com/container-platform/3.3/creating_images/guidelines.html
RUN chgrp -R 0 /var/log /var/cache /run/pid /spool/nginx /var/run /run /tmp /etc/uwsgi /etc/nginx.d && \
    chmod -R g+rwX /var/log /var/cache /run/pid /spool/nginx /var/run /run /tmp /etc/uwsgi /etc/nginx.d && \
    chown -R nginx:root ${HOME} && \
    chmod -R 777 ${HOME} /etc/passwd

USER default
# enter
WORKDIR ${HOME}
ENTRYPOINT ["entrypoint.sh"]
CMD ["supervisord"]
