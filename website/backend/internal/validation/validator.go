package validation

import (
	"fmt"
	"regexp"
	"strings"
)

var (
	emailRegex           = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	uuidRegex            = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
	sqlInjectionPatterns = []string{
		"';", "--", "/*", "*/", "xp_", "sp_", "exec", "execute",
		"insert", "update", "delete", "drop", "create", "alter",
		"script", "javascript:", "onload=", "onerror=", "<script",
	}
)

func ValidateEmail(email string) error {
	if !emailRegex.MatchString(email) {
		return fmt.Errorf("invalid email format")
	}
	return nil
}

func ValidateUUID(uuid string) error {
	if !uuidRegex.MatchString(uuid) {
		return fmt.Errorf("invalid UUID format")
	}
	return nil
}

func SanitizeInput(input string) string {
	// Remove potentially dangerous characters
	input = strings.TrimSpace(input)

	// Check for SQL injection patterns
	lowerInput := strings.ToLower(input)
	for _, pattern := range sqlInjectionPatterns {
		if strings.Contains(lowerInput, pattern) {
			// Log potential SQL injection attempt
			return ""
		}
	}

	// HTML encode special characters
	input = strings.ReplaceAll(input, "<", "&lt;")
	input = strings.ReplaceAll(input, ">", "&gt;")
	input = strings.ReplaceAll(input, "\"", "&quot;")
	input = strings.ReplaceAll(input, "'", "&#x27;")
	input = strings.ReplaceAll(input, "/", "&#x2F;")

	return input
}

func ValidateResourceName(name string) error {
	if len(name) < 3 || len(name) > 63 {
		return fmt.Errorf("resource name must be between 3 and 63 characters")
	}

	// Azure resource naming rules
	match, _ := regexp.MatchString(`^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$`, name)
	if !match {
		return fmt.Errorf("resource name must start and end with alphanumeric characters and can contain hyphens")
	}

	return nil
}
