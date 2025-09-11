#!/bin/bash

# Manual Docker Image Build and Push Script
# Usage: ./push-images.sh [build|push|both] [registry-username]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
ACTION="${1:-both}"
REGISTRY_USER="${2:-}"
IMAGE_PREFIX="analytics-infra"
TAG="${3:-latest}"

# Services to build
SERVICES=(
    "api-receiver:./ingestion/src"
    "data-validator:./validation/src"
    "health-monitor:./monitoring/health-monitor"
)

# Check if registry username is provided
if [ -z "$REGISTRY_USER" ]; then
    print_error "Registry username is required!"
    echo "Usage: $0 [build|push|both] [registry-username] [tag]"
    echo "Example: $0 both myusername latest"
    exit 1
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running!"
    exit 1
fi

# Login to Docker Hub
login_docker() {
    print_status "Logging in to Docker Hub..."
    if docker login; then
        print_success "Successfully logged in to Docker Hub"
    else
        print_error "Failed to login to Docker Hub"
        exit 1
    fi
}

# Build images
build_images() {
    print_status "Building Docker images..."
    
    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_path <<< "$service_info"
        image_name="${REGISTRY_USER}/${IMAGE_PREFIX}-${service_name}"
        
        print_status "Building ${image_name}:${TAG}..."
        
        if docker build -t "${image_name}:${TAG}" -t "${image_name}:latest" "$service_path"; then
            print_success "Built ${image_name}:${TAG}"
        else
            print_error "Failed to build ${image_name}:${TAG}"
            exit 1
        fi
    done
    
    print_success "All images built successfully!"
}

# Push images
push_images() {
    print_status "Pushing Docker images to Docker Hub..."
    
    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_path <<< "$service_info"
        image_name="${REGISTRY_USER}/${IMAGE_PREFIX}-${service_name}"
        
        print_status "Pushing ${image_name}:${TAG}..."
        
        if docker push "${image_name}:${TAG}"; then
            print_success "Pushed ${image_name}:${TAG}"
        else
            print_error "Failed to push ${image_name}:${TAG}"
            exit 1
        fi
        
        # Also push latest tag
        if [ "$TAG" != "latest" ]; then
            print_status "Pushing ${image_name}:latest..."
            if docker push "${image_name}:latest"; then
                print_success "Pushed ${image_name}:latest"
            else
                print_error "Failed to push ${image_name}:latest"
                exit 1
            fi
        fi
    done
    
    print_success "All images pushed successfully!"
}

# List images
list_images() {
    print_status "Built images:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep "$REGISTRY_USER/$IMAGE_PREFIX"
}

# Show help
show_help() {
    echo "Docker Image Build and Push Script"
    echo
    echo "Usage: $0 [COMMAND] [registry-username] [tag]"
    echo
    echo "Commands:"
    echo "  build     Build Docker images locally"
    echo "  push      Push images to Docker Hub"
    echo "  both      Build and push images (default)"
    echo "  list      List built images"
    echo "  help      Show this help message"
    echo
    echo "Arguments:"
    echo "  registry-username    Your Docker Hub username (required)"
    echo "  tag                 Image tag (default: latest)"
    echo
    echo "Examples:"
    echo "  $0 build myusername                    # Build images with 'latest' tag"
    echo "  $0 push myusername v1.0.0             # Push images with 'v1.0.0' tag"
    echo "  $0 both myusername latest             # Build and push with 'latest' tag"
    echo "  $0 list myusername                    # List built images"
    echo
    echo "Images that will be built:"
    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_path <<< "$service_info"
        echo "  - ${REGISTRY_USER}/${IMAGE_PREFIX}-${service_name}:${TAG}"
    done
}

# Main script logic
case "$ACTION" in
    build)
        print_status "Building images for registry: $REGISTRY_USER"
        build_images
        list_images
        ;;
    push)
        print_status "Pushing images for registry: $REGISTRY_USER"
        login_docker
        push_images
        ;;
    both)
        print_status "Building and pushing images for registry: $REGISTRY_USER"
        build_images
        list_images
        echo
        login_docker
        push_images
        ;;
    list)
        list_images
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $ACTION"
        show_help
        exit 1
        ;;
esac

print_success "Operation completed successfully!"
