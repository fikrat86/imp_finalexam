# Sample Dockerfile for Wild Rydes Application
# This is a simple example - replace with your actual application

# Use official nginx image as base
FROM nginx:alpine

# Copy custom HTML content
COPY index.html /usr/share/nginx/html/
COPY styles.css /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
