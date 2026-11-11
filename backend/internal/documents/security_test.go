package documents

import (
	"fmt"
	"strings"
	"testing"
)

func setupTestService() (*Service, string, string, string, string) {
	svc := NewService()
	groupID := "group_alpha"
	ownerID := "user_owner"
	adminID := "user_admin"
	moderatorID := "user_mod"
	memberID := "user_member"
	restrictedID := "user_restricted"

	svc.SetMemberRole(groupID, ownerID, RoleOwner)
	svc.SetMemberRole(groupID, adminID, RoleAdmin)
	svc.SetMemberRole(groupID, moderatorID, RoleModerator)
	svc.SetMemberRole(groupID, memberID, RoleMember)
	svc.SetMemberRole(groupID, restrictedID, RoleRestricted)

	return svc, groupID, ownerID, memberID, restrictedID
}

func TestIDOR_NonMemberCannotAccessDocument(t *testing.T) {
	svc, groupID, ownerID, _, _ := setupTestService()

	// Owner creates document
	doc, err := svc.CreateDocument(ownerID, groupID, "Spécifications", "Contenu E2EE", nil, 1.5, 14.0)
	if err != nil {
		t.Fatalf("Failed to create document: %v", err)
	}

	// Outsider attempts to get document from another group
	_, err = svc.GetDocument("user_outsider", groupID)
	if err != ErrNotGroupMember {
		t.Errorf("Expected ErrNotGroupMember for outsider, got: %v", err)
	}

	// Outsider attempts to update document
	_, _, err = svc.UpdateDocument("user_outsider", groupID, doc.ID, 1, "Hacked", nil, 1.5, 14.0, PublishInPlace)
	if err != ErrNotGroupMember {
		t.Errorf("Expected ErrNotGroupMember on update attempt, got: %v", err)
	}
}

func TestRBAC_PrivilegeEscalationPrevented(t *testing.T) {
	svc, groupID, ownerID, memberID, restrictedID := setupTestService()

	doc, err := svc.CreateDocument(ownerID, groupID, "Doc", "Texte", nil, 1.5, 14.0)
	if err != nil {
		t.Fatalf("CreateDocument failed: %v", err)
	}

	// 1. Member cannot freeze document
	err = svc.FreezeDocument(memberID, groupID, doc.ID)
	if err != ErrPermissionDenied {
		t.Errorf("Expected ErrPermissionDenied when member freezes, got: %v", err)
	}

	// 2. Restricted member cannot edit document
	_, _, err = svc.UpdateDocument(restrictedID, groupID, doc.ID, 1, "Modif", nil, 1.5, 14.0, PublishInPlace)
	if err != ErrPermissionDenied {
		t.Errorf("Expected ErrPermissionDenied when restricted member edits, got: %v", err)
	}

	// 3. Moderator lacks role assignment permission
	modID := "user_mod"
	err = svc.AssignMemberRole(modID, groupID, memberID, RoleAdmin)
	if err != ErrPermissionDenied {
		t.Errorf("Expected ErrPermissionDenied when mod attempts to assign roles, got: %v", err)
	}

	// 4. Admin cannot promote anyone to Owner
	adminID := "user_admin"
	err = svc.AssignMemberRole(adminID, groupID, memberID, RoleOwner)
	if err != ErrInvalidRoleHierarchy {
		t.Errorf("Expected ErrInvalidRoleHierarchy when admin tries to assign owner, got: %v", err)
	}

	// 5. Non-owner cannot demote or remove owner
	err = svc.AssignMemberRole(adminID, groupID, ownerID, RoleMember)
	if err != ErrOwnerImmutable {
		t.Errorf("Expected ErrOwnerImmutable when admin tries to demote owner, got: %v", err)
	}
}

func TestFrozenDocument_EnforcesImmutability(t *testing.T) {
	svc, groupID, ownerID, memberID, _ := setupTestService()

	doc, err := svc.CreateDocument(ownerID, groupID, "Doc Figé", "Texte Initial", map[string]string{
		"tableau1": "<table><tr><td>Donnée</td></tr></table>",
	}, 1.5, 14.0)
	if err != nil {
		t.Fatalf("CreateDocument failed: %v", err)
	}

	// Owner freezes document
	err = svc.FreezeDocument(ownerID, groupID, doc.ID)
	if err != nil {
		t.Fatalf("FreezeDocument failed: %v", err)
	}

	// Member attempts to update frozen document
	_, _, err = svc.UpdateDocument(memberID, groupID, doc.ID, 1, "Nouveau Texte", nil, 1.5, 14.0, PublishInPlace)
	if err != ErrDocumentFrozen {
		t.Errorf("Expected ErrDocumentFrozen when modifying frozen document, got: %v", err)
	}

	// Member attempts to delete component from frozen document
	err = svc.DeleteComponent(memberID, groupID, doc.ID, "tableau1", true)
	if err != ErrDocumentFrozen {
		t.Errorf("Expected ErrDocumentFrozen when deleting component from frozen doc, got: %v", err)
	}

	// Admin attempts to restore version on frozen document
	adminID := "user_admin"
	_, err = svc.RestoreVersion(adminID, groupID, doc.ID, 1)
	if err != ErrDocumentFrozen {
		t.Errorf("Expected ErrDocumentFrozen when restoring version on frozen doc, got: %v", err)
	}

	// Only authorized admin/owner can unfreeze
	err = svc.UnfreezeDocument(memberID, groupID, doc.ID)
	if err != ErrPermissionDenied {
		t.Errorf("Expected ErrPermissionDenied when member unfreezes, got: %v", err)
	}

	err = svc.UnfreezeDocument(ownerID, groupID, doc.ID)
	if err != nil {
		t.Fatalf("UnfreezeDocument by owner failed: %v", err)
	}

	// Once unfrozen, edits succeed
	updated, _, err := svc.UpdateDocument(memberID, groupID, doc.ID, 1, "Texte Après Défigement", nil, 1.5, 14.0, PublishInPlace)
	if err != nil {
		t.Fatalf("Expected update to succeed after unfreeze, got: %v", err)
	}
	if updated.CurrentVersion != 2 {
		t.Errorf("Expected version 2, got %d", updated.CurrentVersion)
	}
}

func TestAntiDoS_ResourceLimitsEnforced(t *testing.T) {
	svc, groupID, ownerID, _, _ := setupTestService()

	// 1. Oversized document (> 5 MB)
	oversizedContent := strings.Repeat("A", MaxDocumentSizeBytes+1024)
	_, err := svc.CreateDocument(ownerID, groupID, "Grand Doc", oversizedContent, nil, 1.5, 14.0)
	if err != ErrDocumentTooLarge {
		t.Errorf("Expected ErrDocumentTooLarge, got: %v", err)
	}

	// 2. Oversized component (> 256 KB)
	oversizedComp := strings.Repeat("B", MaxComponentSizeBytes+512)
	_, err = svc.CreateDocument(ownerID, groupID, "Doc", "Texte", map[string]string{
		"comp1": oversizedComp,
	}, 1.5, 14.0)
	if err != ErrComponentTooLarge {
		t.Errorf("Expected ErrComponentTooLarge, got: %v", err)
	}

	// 3. Too many components (> 200)
	tooManyComps := make(map[string]string)
	for i := 0; i < MaxComponentsCount+1; i++ {
		tooManyComps[fmt.Sprintf("comp_%d", i)] = "data"
	}
	_, err = svc.CreateDocument(ownerID, groupID, "Doc", "Texte", tooManyComps, 1.5, 14.0)
	if err != ErrTooManyComponents {
		t.Errorf("Expected ErrTooManyComponents, got: %v", err)
	}
}

func TestOptimisticConcurrency_VersionConflictPrevented(t *testing.T) {
	svc, groupID, ownerID, memberID, _ := setupTestService()

	doc, err := svc.CreateDocument(ownerID, groupID, "Doc", "Version 1", nil, 1.5, 14.0)
	if err != nil {
		t.Fatalf("CreateDocument failed: %v", err)
	}

	// User A updates document to version 2
	_, _, err = svc.UpdateDocument(ownerID, groupID, doc.ID, 1, "Version 2 par User A", nil, 1.5, 14.0, PublishInPlace)
	if err != nil {
		t.Fatalf("First update failed: %v", err)
	}

	// User B attempts to update with stale expectedVersion = 1
	_, _, err = svc.UpdateDocument(memberID, groupID, doc.ID, 1, "Version conflictuelle par User B", nil, 1.5, 14.0, PublishInPlace)
	if err == nil || !strings.Contains(err.Error(), "concurrent modification detected") {
		t.Errorf("Expected ErrConcurrentModification, got: %v", err)
	}
}

func TestComponentDeletion_SafeguardReferencedVariables(t *testing.T) {
	svc, groupID, ownerID, memberID, _ := setupTestService()

	doc, err := svc.CreateDocument(ownerID, groupID, "Rapport", "Voici le bilan :\n{{tableau1}}\nFin du rapport.", map[string]string{
		"tableau1": "<table><tr><td>Chiffres</td></tr></table>",
	}, 1.5, 14.0)
	if err != nil {
		t.Fatalf("CreateDocument failed: %v", err)
	}

	// Attempting to delete without force while still referenced must fail
	err = svc.DeleteComponent(memberID, groupID, doc.ID, "tableau1", false)
	if err != ErrComponentReferenced {
		t.Errorf("Expected ErrComponentReferenced when deleting referenced component, got: %v", err)
	}

	// Force deletion succeeds
	err = svc.DeleteComponent(memberID, groupID, doc.ID, "tableau1", true)
	if err != nil {
		t.Errorf("Expected forced deletion to succeed, got: %v", err)
	}
}

func TestImmutableVersionsAndAuditLogs(t *testing.T) {
	svc, groupID, ownerID, _, _ := setupTestService()

	doc, err := svc.CreateDocument(ownerID, groupID, "Architecture", "Texte V1", map[string]string{
		"calc1": "<math>x = 1</math>",
	}, 1.5, 14.0)
	if err != nil {
		t.Fatalf("CreateDocument failed: %v", err)
	}

	// Update to V2 with new text and updated component
	_, _, err = svc.UpdateDocument(ownerID, groupID, doc.ID, 1, "Texte V2", map[string]string{
		"calc1": "<math>x = 2</math>",
	}, 1.6, 16.0, PublishPostToChat)
	if err != nil {
		t.Fatalf("Update to V2 failed: %v", err)
	}

	// Update to V3
	_, _, err = svc.UpdateDocument(ownerID, groupID, doc.ID, 2, "Texte V3", map[string]string{
		"calc1": "<math>x = 3</math>",
	}, 1.6, 16.0, PublishInPlace)
	if err != nil {
		t.Fatalf("Update to V3 failed: %v", err)
	}

	// Check versions history
	versions, err := svc.GetVersions(ownerID, groupID, doc.ID)
	if err != nil {
		t.Fatalf("GetVersions failed: %v", err)
	}
	if len(versions) != 3 {
		t.Fatalf("Expected 3 versions, got %d", len(versions))
	}

	// Restore V1
	restored, err := svc.RestoreVersion(ownerID, groupID, doc.ID, 1)
	if err != nil {
		t.Fatalf("RestoreVersion to V1 failed: %v", err)
	}
	if restored.CurrentVersion != 4 {
		t.Errorf("Expected version 4 after restore, got %d", restored.CurrentVersion)
	}
	if restored.EncryptedContent != "Texte V1" {
		t.Errorf("Expected restored content 'Texte V1', got '%s'", restored.EncryptedContent)
	}
	if restored.Components["calc1"].EncryptedPayload != "<math>x = 1</math>" {
		t.Errorf("Expected restored component snapshot '<math>x = 1</math>', got '%s'", restored.Components["calc1"].EncryptedPayload)
	}

	// Check audit logs
	logs, err := svc.GetAuditLogs(ownerID, groupID, doc.ID)
	if err != nil {
		t.Fatalf("GetAuditLogs failed: %v", err)
	}
	if len(logs) < 4 {
		t.Errorf("Expected at least 4 audit logs, got %d", len(logs))
	}
}
