FROM ubuntu

COPY icinga24.sh /tmp/icinga24.sh
COPY run.sh /

RUN chmod +x /tmp/icinga24.sh && chmod +x /run.sh
RUN /tmp/icinga24.sh

VOLUME ["/icinga2conf","/mysql","/icingaweb2"]

EXPOSE 80 5667

CMD ["/run.sh"]
