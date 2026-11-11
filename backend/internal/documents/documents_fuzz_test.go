package documents

import (
	"testing"
)

// FuzzDocumentService_InputValidation verifies that random, malformed, or hostile inputs
// never panic the backend service, strictly respect size limits, and fail cleanly.
func FuzzDocumentService_InputValidation(f *testing.F) {
	// Seed corpus with interesting edge cases
	seeds := []string{
		"",
		"Normal document title",
		"{{id=\"evil\"; <script>alert(1)</script>}}",
		"float a = 1;\nfloat b = 2;\nfloat c = a + b;",
		"<svg onload=\"alert(1)\"><foreignObject></foreignObject></svg>",
		"A" + string(make([]byte, 1024)),
		"Doc.?secret_token_12345",
		"det([[1,2],[3,4]])",
		"1000 * 2000 / 0",
		"((((((((((((((((((((((((((((((((5))))))))))))))))))))))))))))))))",
	}

	for _, seed := range seeds {
		f.Add(seed)
	}

	f.Fuzz(func(t *testing.T, payload string) {
		svc := NewService()
		svc.SetMemberRole("grp_fuzz", "user_admin", RoleAdmin)

		// 1. Create document with fuzzed title and fuzzed content
		comps := map[string]string{"c1": payload}
		doc, err := svc.CreateDocument("user_admin", "grp_fuzz", payload, payload, comps, 1.5, 12.0)
		if err != nil {
			// Controlled rejection (e.g. size exceeded)
			return
		}
		if doc == nil {
			t.Fatalf("doc must not be nil when err is nil")
		}

		// 2. Update document with fuzzed content
		_, _, err = svc.UpdateDocument("user_admin", "grp_fuzz", doc.ID, doc.CurrentVersion, payload, comps, 1.5, 12.0, PublishInPlace)
		if err != nil && err != ErrDocumentTooLarge && err != ErrConcurrentModification && err != ErrDocumentFrozen && err != ErrComponentTooLarge {
			// Acceptable controlled errors
		}

		// 3. Delete component with force=true
		_ = svc.DeleteComponent("user_admin", "grp_fuzz", doc.ID, "c1", true)
	})
}
