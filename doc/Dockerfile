FROM nginx:1.21.3

ARG CI_PROJECT_DIR
ARG DOC_DIR
ARG DOC_PATH

WORKDIR $CI_PROJECT_DIR/$DOC_DIR

# Copy generated files to nginx default html directory
COPY $DOC_PATH /usr/share/nginx/html/atlas-pipeline

# Copy nginx custom configuration to default directory
COPY nginx.conf /etc/nginx/nginx.conf
# Expose port
EXPOSE 8080
# Run nginx server
CMD ["nginx", "-g", "daemon off;"]
