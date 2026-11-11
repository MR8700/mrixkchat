-- Migration: 000002_collaborative_documents_and_permissions.up.sql
-- Description: RBAC permissions matrix, Collaborative Group Documents (E2EE), Components, Immutable Versions, and Audit Trail

-- 1. Role Permissions Matrix
CREATE TABLE IF NOT EXISTS group_role_permissions (
    role VARCHAR(32) NOT NULL, -- OWNER, ADMIN, MODERATOR, MEMBER, RESTRICTED
    permission VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (role, permission)
);

-- Seed Default Permission Matrix
INSERT INTO group_role_permissions (role, permission) VALUES
    -- OWNER: Full administrative, moderation, and document authority
    ('OWNER', 'group.manage'),
    ('OWNER', 'member.invite'),
    ('OWNER', 'member.remove'),
    ('OWNER', 'role.assign'),
    ('OWNER', 'moderation.warn'),
    ('OWNER', 'moderation.restrict'),
    ('OWNER', 'document.create'),
    ('OWNER', 'document.edit'),
    ('OWNER', 'document.publish'),
    ('OWNER', 'document.freeze'),
    ('OWNER', 'document.unfreeze'),
    ('OWNER', 'document.restore'),
    ('OWNER', 'document.delete'),
    ('OWNER', 'component.manage'),

    -- ADMIN: All administrative capabilities except removing or modifying the owner
    ('ADMIN', 'group.manage'),
    ('ADMIN', 'member.invite'),
    ('ADMIN', 'member.remove'),
    ('ADMIN', 'role.assign'),
    ('ADMIN', 'moderation.warn'),
    ('ADMIN', 'moderation.restrict'),
    ('ADMIN', 'document.create'),
    ('ADMIN', 'document.edit'),
    ('ADMIN', 'document.publish'),
    ('ADMIN', 'document.freeze'),
    ('ADMIN', 'document.unfreeze'),
    ('ADMIN', 'document.restore'),
    ('ADMIN', 'document.delete'),
    ('ADMIN', 'component.manage'),

    -- MODERATOR: Invites, moderation actions, document editing and component management
    ('MODERATOR', 'member.invite'),
    ('MODERATOR', 'moderation.warn'),
    ('MODERATOR', 'moderation.restrict'),
    ('MODERATOR', 'document.create'),
    ('MODERATOR', 'document.edit'),
    ('MODERATOR', 'document.publish'),
    ('MODERATOR', 'document.restore'),
    ('MODERATOR', 'component.manage'),

    -- MEMBER: Standard collaboration rights (subject to group policy)
    ('MEMBER', 'document.edit'),
    ('MEMBER', 'document.publish'),
    ('MEMBER', 'component.manage')
ON CONFLICT (role, permission) DO NOTHING;

-- 2. Collaborative Documents (Strictly E2EE envelopes; server never sees plaintext)
CREATE TABLE IF NOT EXISTS group_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    state VARCHAR(32) NOT NULL DEFAULT 'ACTIVE', -- DRAFT, ACTIVE, FROZEN, ARCHIVED, DELETED
    current_version INT NOT NULL DEFAULT 1,
    encrypted_content TEXT NOT NULL, -- AES-256-GCM ciphertext
    line_spacing NUMERIC(3,2) NOT NULL DEFAULT 1.50,
    paragraph_spacing NUMERIC(4,1) NOT NULL DEFAULT 14.0,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_group_primary_doc UNIQUE (group_id)
);
CREATE INDEX IF NOT EXISTS idx_group_docs_group_state ON group_documents(group_id, state);

-- 3. Document Components (Independently versioned macros: tableau1, formule1, etc.)
CREATE TABLE IF NOT EXISTS group_document_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES group_documents(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    component_type VARCHAR(32) NOT NULL, -- TABLE, MATH, DIAGRAM, GRAPH, CUSTOM
    encrypted_payload TEXT NOT NULL, -- AES-256-GCM ciphertext
    version INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_doc_comp_version UNIQUE (document_id, name, version)
);
CREATE INDEX IF NOT EXISTS idx_doc_components_lookup ON group_document_components(document_id, name, is_active);

-- 4. Immutable Document Versions (History & Rollback)
CREATE TABLE IF NOT EXISTS group_document_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES group_documents(id) ON DELETE CASCADE,
    version_num INT NOT NULL,
    encrypted_content TEXT NOT NULL,
    encrypted_components_snapshot TEXT NOT NULL,
    state VARCHAR(32) NOT NULL,
    publish_type VARCHAR(32) NOT NULL DEFAULT 'IN_PLACE', -- IN_PLACE, POST_TO_CHAT
    modified_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    signature VARCHAR(512),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_doc_version UNIQUE (document_id, version_num)
);
CREATE INDEX IF NOT EXISTS idx_doc_versions_doc_ver ON group_document_versions(document_id, version_num DESC);

-- 5. Document Audit Trail (Non-repudiation and security tracking)
CREATE TABLE IF NOT EXISTS group_document_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES group_documents(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action VARCHAR(64) NOT NULL, -- CREATED, EDITED, FROZEN, UNFROZEN, RESTORED, COMPONENT_ADDED, COMPONENT_MODIFIED, COMPONENT_DELETED
    from_version INT,
    to_version INT,
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_doc_audit_doc_created ON group_document_audit_logs(document_id, created_at DESC);
