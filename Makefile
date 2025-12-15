TAG ?= v1.3.1

generate-manifest:
	scripts/generate_manifest.sh ${TAG}
	cd scripts/remove_duplicates; go build remove_duplicate.go;./remove_duplicate;cd ..

generate-kustomize:
	scripts/generate_kustomize.sh ${TAG}
	cd scripts/kustomize_cleanup; go build kustomize_cleanup.go;./kustomize_cleanup;cd ..
	scripts/generate_crds.sh ${TAG}

upload-docker-images:
	scripts/upload_docker_images.sh ${TAG}

generate-ui-manifest:
	scripts/generate_ui_manifest.sh ${TAG}
	cd scripts/remove_duplicates; go build remove_duplicate.go;./remove_duplicate;cd ..
