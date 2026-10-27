# Build the LFS assets first: ./prepare-public.sh
# Then: docker build -t use-craft-apps . && docker run -p 8080:80 use-craft-apps
FROM nginx:alpine

COPY public/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]