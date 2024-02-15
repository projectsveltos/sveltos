TAG ?= v0.24.0

generate-manifest:
	scripts/generate_manifest.sh ${TAG}
	cd scripts/remove_duplicates; go build remove_duplicate.go;./remove_duplicate;cd ..

upload-docker-images:
	scripts/upload_docker_images.sh ${TAG} ${DOCKER_CONFIG}
