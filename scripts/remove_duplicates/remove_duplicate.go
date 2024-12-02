package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"

	"github.com/projectsveltos/libsveltos/lib/k8s_utils"
)

const (
	permission0644 = 0644
)

func main() {
	cwd, err := os.Getwd()
	if err != nil {
		panic(1)
	}

	manifestDir := filepath.Join(filepath.Dir(filepath.Dir(cwd)), "manifest")
	updateFile(manifestDir, "manifest.yaml")
	updateFile(manifestDir, "dashboard-manifest.yaml")
	updateFile(manifestDir, "agents_in_mgmt_cluster_manifest.yaml")
}

// get all resources in file and removes duplicate namespace entries
func updateFile(fileDir, fileName string) {
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

	foundNamespace := false
	for i := range resources {
		if resources[i].GetKind() == "Namespace" {
			if foundNamespace {
				continue
			}
			fmt.Printf("add resource %s:%s/%s\n", resources[i].GetKind(), resources[i].GetNamespace(), resources[i].GetName())
			foundNamespace = true
			writeUnstructuredToFile(f, resources[i])
		} else {
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

		u, err := k8s_utils.GetUnstructured([]byte(section))
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
