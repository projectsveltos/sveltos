TAG ?= v0.4.1

generate-manifest:
	scripts/generate_manifest.sh ${TAG}

upload-docker-images:
	scripts/upload_docker_images.sh ${TAG}
