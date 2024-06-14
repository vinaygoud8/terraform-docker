# Use the official Nginx image from Docker Hub
FROM nginx:latest

# Copy your static HTML file to the nginx server's default location
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

# Start Nginx server
CMD ["nginx", "-g", "daemon off;"]