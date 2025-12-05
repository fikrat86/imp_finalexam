# Sample Dockerfile for Wild Rydes Application
# Using Amazon ECR Public registry to avoid Docker Hub rate limits

# Use nginx from Amazon ECR Public Gallery
FROM public.ecr.aws/nginx/nginx:alpine

# Copy custom HTML content
COPY index.html /usr/share/nginx/html/
COPY styles.css /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
