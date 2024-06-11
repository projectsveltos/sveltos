TAG ?= v0.32.0

generate-manifest:
	scripts/generate_manifest.sh ${TAG}
	cd scripts/remove_duplicates; go build remove_duplicate.go;./remove_duplicate;cd ..

generate-kustomize:
	scripts/generate_kustomize.sh ${TAG}
	cd scripts/kustomize_cleanup; go build kustomize_cleanup.go;./kustomize_cleanup;cd ..

upload-docker-images:
	scripts/upload_docker_images.sh ${TAG}
