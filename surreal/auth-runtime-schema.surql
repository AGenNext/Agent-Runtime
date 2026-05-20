-- Agent-Runtime auth/runtime schema
-- Semantic source: Agent-Graph
-- Enforcement/runtime layer: SurrealDB + SurrealQL

DEFINE TABLE auth_identity SCHEMAFULL;
DEFINE FIELD identity_type ON TABLE auth_identity TYPE string ASSERT $value INSIDE ["human", "agent", "service", "organization"];
DEFINE FIELD subject ON TABLE auth_identity TYPE string;
DEFINE FIELD email ON TABLE auth_identity TYPE option<string>;
DEFINE FIELD phone ON TABLE auth_identity TYPE option<string>;
DEFINE FIELD display_name ON TABLE auth_identity TYPE option<string>;
DEFINE FIELD status ON TABLE auth_identity TYPE string DEFAULT "active" ASSERT $value INSIDE ["pending", "active", "suspended", "frozen", "deleted"];
DEFINE FIELD provider ON TABLE auth_identity TYPE string DEFAULT "local";
DEFINE FIELD provider_subject ON TABLE auth_identity TYPE option<string>;
DEFINE FIELD password_hash_ref ON TABLE auth_identity TYPE option<string>;
DEFINE FIELD metadata ON TABLE auth_identity TYPE object FLEXIBLE DEFAULT {};
DEFINE FIELD graph_ref ON TABLE auth_identity TYPE option<string>;
DEFINE FIELD created_at ON TABLE auth_identity TYPE datetime DEFAULT time::now();
DEFINE FIELD updated_at ON TABLE auth_identity TYPE datetime DEFAULT time::now();

DEFINE INDEX auth_identity_subject ON TABLE auth_identity FIELDS subject UNIQUE;
DEFINE INDEX auth_identity_email ON TABLE auth_identity FIELDS email;
DEFINE INDEX auth_identity_status ON TABLE auth_identity FIELDS status;
DEFINE INDEX auth_identity_provider_subject ON TABLE auth_identity FIELDS provider, provider_subject UNIQUE;

DEFINE TABLE auth_session SCHEMAFULL;
DEFINE FIELD identity ON TABLE auth_session TYPE record<auth_identity>;
DEFINE FIELD session_token_hash ON TABLE auth_session TYPE string;
DEFINE FIELD refresh_token_hash ON TABLE auth_session TYPE option<string>;
DEFINE FIELD jwt_id ON TABLE auth_session TYPE option<string>;
DEFINE FIELD status ON TABLE auth_session TYPE string DEFAULT "active" ASSERT $value INSIDE ["active", "revoked", "expired"];
DEFINE FIELD issued_at ON TABLE auth_session TYPE datetime DEFAULT time::now();
DEFINE FIELD expires_at ON TABLE auth_session TYPE datetime;
DEFINE FIELD revoked_at ON TABLE auth_session TYPE option<datetime>;
DEFINE FIELD ip_address ON TABLE auth_session TYPE option<string>;
DEFINE FIELD user_agent ON TABLE auth_session TYPE option<string>;
DEFINE FIELD metadata ON TABLE auth_session TYPE object FLEXIBLE DEFAULT {};
DEFINE FIELD created_at ON TABLE auth_session TYPE datetime DEFAULT time::now();
DEFINE FIELD updated_at ON TABLE auth_session TYPE datetime DEFAULT time::now();

DEFINE INDEX auth_session_identity ON TABLE auth_session FIELDS identity;
DEFINE INDEX auth_session_token_hash ON TABLE auth_session FIELDS session_token_hash UNIQUE;
DEFINE INDEX auth_session_refresh_hash ON TABLE auth_session FIELDS refresh_token_hash UNIQUE;
DEFINE INDEX auth_session_status ON TABLE auth_session FIELDS status;
DEFINE INDEX auth_session_expires_at ON TABLE auth_session FIELDS expires_at;

DEFINE TABLE auth_magic_link SCHEMAFULL;
DEFINE FIELD identity ON TABLE auth_magic_link TYPE option<record<auth_identity>>;
DEFINE FIELD email ON TABLE auth_magic_link TYPE string;
DEFINE FIELD token_hash ON TABLE auth_magic_link TYPE string;
DEFINE FIELD purpose ON TABLE auth_magic_link TYPE string DEFAULT "login" ASSERT $value INSIDE ["signup", "login", "verify_email", "passwordless"];
DEFINE FIELD status ON TABLE auth_magic_link TYPE string DEFAULT "pending" ASSERT $value INSIDE ["pending", "used", "expired", "revoked"];
DEFINE FIELD expires_at ON TABLE auth_magic_link TYPE datetime;
DEFINE FIELD used_at ON TABLE auth_magic_link TYPE option<datetime>;
DEFINE FIELD redirect_to ON TABLE auth_magic_link TYPE option<string>;
DEFINE FIELD metadata ON TABLE auth_magic_link TYPE object FLEXIBLE DEFAULT {};
DEFINE FIELD created_at ON TABLE auth_magic_link TYPE datetime DEFAULT time::now();
DEFINE FIELD updated_at ON TABLE auth_magic_link TYPE datetime DEFAULT time::now();

DEFINE INDEX auth_magic_link_token_hash ON TABLE auth_magic_link FIELDS token_hash UNIQUE;
DEFINE INDEX auth_magic_link_email ON TABLE auth_magic_link FIELDS email;
DEFINE INDEX auth_magic_link_status ON TABLE auth_magic_link FIELDS status;
DEFINE INDEX auth_magic_link_expires_at ON TABLE auth_magic_link FIELDS expires_at;

DEFINE TABLE auth_oauth_provider SCHEMAFULL;
DEFINE FIELD provider_key ON TABLE auth_oauth_provider TYPE string;
DEFINE FIELD issuer_url ON TABLE auth_oauth_provider TYPE string;
DEFINE FIELD client_id ON TABLE auth_oauth_provider TYPE string;
DEFINE FIELD client_secret_ref ON TABLE auth_oauth_provider TYPE option<string>;
DEFINE FIELD discovery_document ON TABLE auth_oauth_provider TYPE object FLEXIBLE DEFAULT {};
DEFINE FIELD scopes ON TABLE auth_oauth_provider TYPE array<string> DEFAULT [];
DEFINE FIELD status ON TABLE auth_oauth_provider TYPE string DEFAULT "active" ASSERT $value INSIDE ["active", "disabled"];
DEFINE FIELD created_at ON TABLE auth_oauth_provider TYPE datetime DEFAULT time::now();
DEFINE FIELD updated_at ON TABLE auth_oauth_provider TYPE datetime DEFAULT time::now();

DEFINE INDEX auth_oauth_provider_key ON TABLE auth_oauth_provider FIELDS provider_key UNIQUE;
DEFINE INDEX auth_oauth_provider_status ON TABLE auth_oauth_provider FIELDS status;

DEFINE TABLE auth_audit_event SCHEMAFULL;
DEFINE FIELD event_type ON TABLE auth_audit_event TYPE string;
DEFINE FIELD actor_ref ON TABLE auth_audit_event TYPE option<string>;
DEFINE FIELD target_ref ON TABLE auth_audit_event TYPE option<string>;
DEFINE FIELD request_id ON TABLE auth_audit_event TYPE option<string>;
DEFINE FIELD trace_id ON TABLE auth_audit_event TYPE option<string>;
DEFINE FIELD status ON TABLE auth_audit_event TYPE string ASSERT $value INSIDE ["success", "failure", "blocked"];
DEFINE FIELD reason ON TABLE auth_audit_event TYPE option<string>;
DEFINE FIELD payload ON TABLE auth_audit_event TYPE object FLEXIBLE DEFAULT {};
DEFINE FIELD event_time ON TABLE auth_audit_event TYPE datetime DEFAULT time::now();
DEFINE FIELD created_at ON TABLE auth_audit_event TYPE datetime DEFAULT time::now();

DEFINE INDEX auth_audit_event_type ON TABLE auth_audit_event FIELDS event_type;
DEFINE INDEX auth_audit_event_actor ON TABLE auth_audit_event FIELDS actor_ref;
DEFINE INDEX auth_audit_event_target ON TABLE auth_audit_event FIELDS target_ref;
DEFINE INDEX auth_audit_event_time ON TABLE auth_audit_event FIELDS event_time;

DEFINE TABLE owns_session TYPE RELATION IN auth_identity OUT auth_session SCHEMAFULL;
DEFINE FIELD created_at ON TABLE owns_session TYPE datetime DEFAULT time::now();

DEFINE TABLE authenticated_by TYPE RELATION IN auth_identity OUT auth_oauth_provider SCHEMAFULL;
DEFINE FIELD provider_subject ON TABLE authenticated_by TYPE string;
DEFINE FIELD created_at ON TABLE authenticated_by TYPE datetime DEFAULT time::now();
