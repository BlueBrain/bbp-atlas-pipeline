FROM nginx:1.21.3

# Copy generated files to nginx default html directory
# Replace generated/html directory with the one that generated files are placed in
COPY generated/html /usr/share/nginx/html
# Copy nginx custom configuration to default directory
COPY nginx.conf /etc/nginx/nginx.conf
# Expose port
EXPOSE 8080
# Run nginx server
CMD ["nginx", "-g", "daemon off;"]