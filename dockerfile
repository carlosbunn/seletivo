FROM nginxinc/nginx-unprivileged
USER root
RUN echo "{\"service\": {\"oracle\": \"ok\", \"redis\": \"ok\", \"mongo\": \"down\", \"pgsql\": \"down\", \"mysql\": \"ok\"}}"> /usr/share/nginx/html/status.json
RUN chown nginx:nginx /usr/share/nginx/html/status.json
USER nginx 
CMD ["/usr/sbin/nginx","-g","daemon off;"]

