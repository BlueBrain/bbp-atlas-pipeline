FROM nginx:1.21.3

ARG DOC
RUN ls .
RUN ls /builds/dke/apps/blue_brain_atlas_pipeline/doc

# Copy generated files to nginx default html directory
COPY $DOC /usr/share/nginx/html
# Copy nginx custom configuration to default directory
COPY ../nginx.conf /etc/nginx/nginx.conf
# Expose port
EXPOSE 8080
# Run nginx server
CMD ["nginx", "-g", "daemon off;"]
