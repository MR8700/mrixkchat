-- Migration: 000002_collaborative_documents_and_permissions.down.sql
-- Description: Revert collaborative documents, components, versions, audit logs and permissions matrix

DROP TABLE IF EXISTS group_document_audit_logs CASCADE;
DROP TABLE IF EXISTS group_document_versions CASCADE;
DROP TABLE IF EXISTS group_document_components CASCADE;
DROP TABLE IF EXISTS group_documents CASCADE;
DROP TABLE IF EXISTS group_role_permissions CASCADE;
