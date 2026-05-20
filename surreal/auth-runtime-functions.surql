DEFINE FUNCTION OVERWRITE fn::runtime::auth::identity::create($identity: object) -> object {
    LET $record = type::record("auth_identity", <string>$identity.id);
    RETURN UPSERT ONLY $record CONTENT {
        identity_type: $identity.identity_type ?? "human",
        subject: $identity.subject,
        email: $identity.email ?? NONE,
        phone: $identity.phone ?? NONE,
        display_name: $identity.display_name ?? NONE,
        status: $identity.status ?? "active",
        provider: $identity.provider ?? "local",
        provider_subject: $identity.provider_subject ?? NONE,
        password_hash_ref: $identity.password_hash_ref ?? NONE,
        metadata: $identity.metadata ?? {},
        graph_ref: $identity.graph_ref ?? NONE,
        created_at: time::now(),
        updated_at: time::now()
    };
};

DEFINE FUNCTION OVERWRITE fn::runtime::auth::identity::freeze($identity_id: string, $reason: option<string>) -> bool {
    UPDATE ONLY type::record("auth_identity", $identity_id)
    SET status = "frozen", updated_at = time::now();

    CREATE auth_audit_event SET
        event_type = "identity_frozen",
        target_ref = $identity_id,
        status = "blocked",
        reason = $reason ?? "manual freeze",
        event_time = time::now(),
        created_at = time::now();

    RETURN true;
};

DEFINE FUNCTION OVERWRITE fn::runtime::auth::session::create($session: object) -> object {
    LET $record = type::record("auth_session", <string>$session.id);

    LET $created = UPSERT ONLY $record CONTENT {
        identity: type::record("auth_identity", <string>$session.identity_id),
        session_token_hash: $session.session_token_hash,
        refresh_token_hash: $session.refresh_token_hash ?? NONE,
        jwt_id: $session.jwt_id ?? NONE,
        status: "active",
        issued_at: time::now(),
        expires_at: $session.expires_at,
        ip_address: $session.ip_address ?? NONE,
        user_agent: $session.user_agent ?? NONE,
        metadata: $session.metadata ?? {},
        created_at: time::now(),
        updated_at: time::now()
    };

    RELATE type::record("auth_identity", <string>$session.identity_id)
        ->owns_session->$record CONTENT {
            created_at: time::now()
        };

    RETURN $created;
};

DEFINE FUNCTION OVERWRITE fn::runtime::auth::session::revoke($session_id: string, $reason: option<string>) -> bool {
    UPDATE ONLY type::record("auth_session", $session_id)
    SET
        status = "revoked",
        revoked_at = time::now(),
        updated_at = time::now();

    CREATE auth_audit_event SET
        event_type = "session_revoked",
        target_ref = $session_id,
        status = "success",
        reason = $reason ?? "manual revoke",
        event_time = time::now(),
        created_at = time::now();

    RETURN true;
};

DEFINE FUNCTION OVERWRITE fn::runtime::auth::magic_link::create($link: object) -> object {
    LET $record = type::record("auth_magic_link", <string>$link.id);

    RETURN UPSERT ONLY $record CONTENT {
        identity: IF type::is_none($link.identity_id) {
            NONE
        } ELSE {
            type::record("auth_identity", <string>$link.identity_id)
        },
        email: $link.email,
        token_hash: $link.token_hash,
        purpose: $link.purpose ?? "login",
        status: "pending",
        expires_at: $link.expires_at,
        redirect_to: $link.redirect_to ?? NONE,
        metadata: $link.metadata ?? {},
        created_at: time::now(),
        updated_at: time::now()
    };
};

DEFINE FUNCTION OVERWRITE fn::runtime::auth::audit($event: object) -> object {
    RETURN CREATE auth_audit_event CONTENT {
        event_type: $event.event_type,
        actor_ref: $event.actor_ref ?? NONE,
        target_ref: $event.target_ref ?? NONE,
        request_id: $event.request_id ?? NONE,
        trace_id: $event.trace_id ?? NONE,
        status: $event.status ?? "success",
        reason: $event.reason ?? NONE,
        payload: $event.payload ?? {},
        event_time: time::now(),
        created_at: time::now()
    };
};