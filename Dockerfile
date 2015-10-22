FROM ubuntu

COPY ./icinga22.sh /tmp/
COPY ./run.sh /

RUN chmod +x /tmp/icinga22.sh && chmod +x /run.sh
RUN /tmp/icinga22.sh

VOLUME ["/icinga2conf","/mysql","/icingaweb2"]

EXPOSE 80 5667

CMD ["/run.sh"]
