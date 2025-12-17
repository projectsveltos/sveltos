package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"

	libsveltosutils "github.com/projectsveltos/libsveltos/lib/k8s_utils"
)

const (
	permission0644    = 0644
	kustomizeDirName  = "kustomize"
	baseDirName       = "base"
	componentsDirName = "components"
	crdDirName        = "crds"
)

// The generate_kustomize.sh script copies files from vary Sveltos repos.
// Then this runs. Its goal is to finish creating a kustomize directory.
// Following operations are taken care of:
// - Any file in base/components and base/crds is added to kustomization.yaml
// - Namespace resource is removed from every file in base/components
// - Any CRD present in base/components is removed from base/components and a new file
// in base/crds is created for it (this makes sure all CRDs are in base/crds)
// - Update overalys/agentless-mode/kustomization.yaml
func main() {
	cwd, err := os.Getwd()
	if err != nil {
		panic(1)
	}

	// Namespace is present in several component files. Remove namespace from
	// each of those files and create a "namespace.yaml" with it
	updateBaseDir(cwd)

	// Remove CRDs from files in base. A separate file for CRD is created
	// under components/rds
	moveCRDs(cwd)

	// Remove ServiceMonitors
	removeServiceMonitors(cwd)

	// Every file present in base will be added to kustomization.yaml
	updateBaseKustomizationFile(cwd)

	// Every file present in base/crds and base/components will be added to kustomization.yaml
	updateComponentsCrdsKustomizationFile(cwd)

	// Create kustomization.yaml in overlays/agentless-mode listing every file in
	// overlays/agentless-mode
	createOverlaysKustomizationFile(cwd)
}

func removeServiceMonitors(cwd string) {
	baseDir := filepath.Join(filepath.Dir(filepath.Dir(cwd)), kustomizeDirName, baseDirName)
	// Read directory with components contents
	files, err := os.ReadDir(baseDir)
	if err != nil {
		fmt.Println("Error reading directory:", err)
		panic(1)
	}

	// Loop through each file. Any CustomResourceDefinition will be removed from the file
	// and a corresponding file under base/components/crds will be created
	for _, file := range files {
		if !file.IsDir() {
			removeServiceMonitorsFromFile(cwd, baseDir, file.Name())
		}
	}
}

// Remove any ServicerMonitos from filename.
func removeServiceMonitorsFromFile(cwd, fileDir, fileName string) {
	filePath := filepath.Join(fileDir, fileName)
	fmt.Printf("Removing ServiceMonitors from file %s\n", filePath)

	resources := getResources(fileDir, fileName)

	err := os.Remove(filePath)
	if err != nil {
		panic(1)
	}

	f, err := os.OpenFile(filePath, os.O_CREATE|os.O_WRONLY, permission0644)
	if err != nil {
		panic(1)
	}
	defer f.Close()

	for i := range resources {
		if resources[i].GetKind() != "ServiceMonitor" {
			// Leave resource to file
			fmt.Printf("add resource %s:%s/%s\n", resources[i].GetKind(), resources[i].GetNamespace(), resources[i].GetName())
			writeUnstructuredToFile(f, resources[i])
		}
	}

	fmt.Printf("Removed CRD from file %s\n", f.Name())
}

func moveCRDs(cwd string) {
	baseDir := filepath.Join(filepath.Dir(filepath.Dir(cwd)), kustomizeDirName, baseDirName)
	// Read directory with components contents
	files, err := os.ReadDir(baseDir)
	if err != nil {
		fmt.Println("Error reading directory:", err)
		panic(1)
	}

	// Loop through each file. Any CustomResourceDefinition will be removed from the file
	// and a corresponding file under base/components/crds will be created
	for _, file := range files {
		if !file.IsDir() {
			moveCRDsFromFile(cwd, baseDir, file.Name())
		}
	}
}

// Remove any CRD from filename. Create a file for each CRD in components/crds
func moveCRDsFromFile(cwd, fileDir, fileName string) {
	filePath := filepath.Join(fileDir, fileName)
	fmt.Printf("Removing CRDs from file %s\n", filePath)

	resources := getResources(fileDir, fileName)

	err := os.Remove(filePath)
	if err != nil {
		panic(1)
	}

	f, err := os.OpenFile(filePath, os.O_CREATE|os.O_WRONLY, permission0644)
	if err != nil {
		panic(1)
	}
	defer f.Close()

	for i := range resources {
		if resources[i].GetKind() != "CustomResourceDefinition" {
			// Leave resource to file
			fmt.Printf("add resource %s:%s/%s\n", resources[i].GetKind(), resources[i].GetNamespace(), resources[i].GetName())
			writeUnstructuredToFile(f, resources[i])
		} else {
			// Create a separate file under base/crds with this content
			fmt.Printf("create file in components/crds for CRD %s\n", resources[i].GetName())
			fileName := fmt.Sprintf("%s.yaml", resources[i].GetName())
			filePath := filepath.Join(filepath.Dir(filepath.Dir(cwd)), kustomizeDirName, componentsDirName, crdDirName, fileName)
			resourceYAML, err := yaml.Marshal(resources[i].UnstructuredContent())
			if err != nil {
				panic(1)
			}

			err = os.WriteFile(filePath, resourceYAML, 0644)
			if err != nil {
				fmt.Println("failed to write to file", filePath, err)
				panic(1)
			}
		}
	}

	fmt.Printf("Removed CRD from file %s\n", f.Name())
}

// - Remove Namespace from every file in base/
// - Create a base/namespace.yaml
func updateBaseDir(cwd string) {
	baseDir := filepath.Join(filepath.Dir(filepath.Dir(cwd)), kustomizeDirName, baseDirName)

	// Read directory with components contents
	files, err := os.ReadDir(baseDir)
	if err != nil {
		fmt.Println("Error reading directory:", err)
		panic(1)
	}

	// Loop through each file and remove Namespace (if present) from it
	// Other resources are left intact
	for _, file := range files {
		if !file.IsDir() {
			removeNamespace(baseDir, file.Name())
		}
	}

	// Create in base a file containing the projectsveltos Namespace
	createNamespaceFile(baseDir)
}

// - Any file in base is added as resource to kustomization.yaml
// - ../components/crds is added as components
func updateBaseKustomizationFile(cwd string) {
	content := `apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:`

	baseDir := filepath.Join(filepath.Dir(filepath.Dir(cwd)), kustomizeDirName, baseDirName)
	content = appendFilesFromDir(content, baseDir)

	content += `
components:
`
	content += fmt.Sprintf("- ../%s/%s", componentsDirName, crdDirName)

	// Create the file with the content
	filePath := filepath.Join(baseDir, "kustomization.yaml")
	err := os.WriteFile(filePath, []byte(content), 0644)
	if err != nil {
		fmt.Println("Error writing file:", err)
		panic(1)
	}
}

// - Any file in base/components and base/crds is added to kustomization.yaml
func updateComponentsCrdsKustomizationFile(cwd string) {
	content := `apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:`

	crdsDir := filepath.Join(filepath.Dir(filepath.Dir(cwd)), kustomizeDirName, componentsDirName, crdDirName)
	content = appendFilesFromDir(content, crdsDir)

	// Create the file with the content
	filePath := filepath.Join(crdsDir, "kustomization.yaml")
	err := os.WriteFile(filePath, []byte(content), 0644)
	if err != nil {
		fmt.Println("Error writing file:", err)
		panic(1)
	}
}

func appendFilesFromDir(content, directory string) string {
	// Read directory contents with CRDS
	files, err := os.ReadDir(directory)
	if err != nil {
		fmt.Println("Error reading directory:", err)
		panic(1)
	}

	// Loop through each file
	for _, file := range files {
		if !file.IsDir() {
			content += fmt.Sprintf("\n- %s", file.Name())
		}
	}

	return content
}

func createNamespaceFile(fileDir string) {
	content := `apiVersion: v1
kind: Namespace
metadata:
  name: projectsveltos`

	// Create the directory if it doesn't exist
	err := os.MkdirAll(fileDir, 0755)
	if err != nil {
		fmt.Println("Error creating directory:", err)
		panic(1)
	}

	// Create the file with the content
	filePath := filepath.Join(fileDir, "namespace.yaml")
	err = os.WriteFile(filePath, []byte(content), 0644)
	if err != nil {
		fmt.Println("Error writing file:", err)
		panic(1)
	}
}

// get all resources in file and removes namespace entries
func removeNamespace(fileDir, fileName string) {
	filePath := filepath.Join(fileDir, fileName)
	fmt.Printf("Read file %s\n", filePath)

	resources := getResources(fileDir, fileName)

	err := os.Remove(filePath)
	if err != nil {
		panic(1)
	}

	f, err := os.OpenFile(filePath, os.O_CREATE|os.O_WRONLY, permission0644)
	if err != nil {
		panic(1)
	}
	defer f.Close()

	for i := range resources {
		if resources[i].GetKind() != "Namespace" {
			fmt.Printf("add resource %s:%s/%s\n", resources[i].GetKind(), resources[i].GetNamespace(), resources[i].GetName())
			writeUnstructuredToFile(f, resources[i])
		}
	}

	fmt.Printf("Updated file %s\n", f.Name())
}

func getResources(dirName, fileName string) []*unstructured.Unstructured {
	resourceFileName := filepath.Join(dirName, fileName)

	_, err := os.Stat(resourceFileName)
	if os.IsNotExist(err) {
		panic(1)
	}

	content, err := os.ReadFile(resourceFileName)
	if err != nil {
		panic(1)
	}

	resources := make([]*unstructured.Unstructured, 0)
	elements := splitBySeparatorLine(string(content))
	for i := range elements {
		section := removeCommentsAndEmptyLines(elements[i])
		if section == "" {
			continue
		}

		u, err := libsveltosutils.GetUnstructured([]byte(section))
		if err != nil {
			fmt.Printf("failed to get unstructured. Section %s, err %v", section, err)
			panic(1)
		}
		resources = append(resources, u)
	}

	return resources
}

func splitBySeparatorLine(content string) []string {
	var sections []string
	currentSection := ""

	lines := strings.Split(content, "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "---") && strings.TrimSpace(line) == "---" {
			if currentSection != "" {
				sections = append(sections, currentSection)
			}
			currentSection = ""
		} else {
			currentSection += line + "\n" // Include newline for consistency
		}
	}

	// Add the last section if it exists
	if currentSection != "" {
		sections = append(sections, currentSection)
	}

	return sections
}

func removeCommentsAndEmptyLines(text string) string {
	commentLine := regexp.MustCompile(`(?m)^\s*#([^#].*?)$`)
	result := commentLine.ReplaceAllString(text, "")
	emptyLine := regexp.MustCompile(`(?m)^\s*$`)
	result = emptyLine.ReplaceAllString(result, "")
	return result
}

func writeUnstructuredToFile(file *os.File, u *unstructured.Unstructured) error {
	// Marshal the unstructured object to YAML
	yaml, err := yaml.Marshal(u.UnstructuredContent())
	if err != nil {
		return err
	}

	// Write the YAML to the file
	_, err = file.Write(yaml)
	if err != nil {
		return err
	}

	_, err = file.Write([]byte("---\n"))
	if err != nil {
		return err
	}

	return nil
}

// Create overlays/agentless-mode/kustomization.yaml
// All files in overlays/agentless-mode (excluding the patch files) are added as resources
// Patch files are added to patch section
func createOverlaysKustomizationFile(cwd string) {
	content := `apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base
`

	// Those are patch files
	patchFiles := []string{"addon-controller.yaml", "classifier.yaml", "event-manager.yaml", "healthcheck-manager.yaml", "shard-controller.yaml"}
	overalaysDir := filepath.Join(filepath.Dir(filepath.Dir(cwd)), kustomizeDirName, "overlays", "agentless-mode")

	files, err := os.ReadDir(overalaysDir)
	if err != nil {
		fmt.Println("Error reading directory:", err)
		panic(1)
	}

	isPatchFile := func(filename string) bool {
		for _, excludedFile := range patchFiles {
			if filename == excludedFile {
				return true
			}
		}
		return false
	}

	// Loop through each file, exclude patch files
	for _, file := range files {
		if !isPatchFile(file.Name()) {
			content += fmt.Sprintf("- %s\n", file.Name())
		}
	}

	content += `

patches:
`

	for i := range patchFiles {
		content += fmt.Sprintf("- path: %s\n", patchFiles[i])
	}

	// Create the file with the content
	filePath := filepath.Join(overalaysDir, "kustomization.yaml")
	err = os.WriteFile(filePath, []byte(content), 0644)
	if err != nil {
		fmt.Println("Error writing file:", err)
		panic(1)
	}
}
