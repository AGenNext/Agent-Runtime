export type SignupRequest = {
  email: string;
  password?: string;
  display_name?: string;
  metadata?: Record<string, unknown>;
};

export type LoginRequest = {
  email: string;
  password?: string;
};

export type MagicLinkRequest = {
  email: string;
  purpose?: "signup" | "login" | "verify_email" | "passwordless";
  redirect_to?: string;
};

export type AuthResult = {
  identity: {
    id: string;
    email?: string;
    display_name?: string;
    status?: string;
  };
  session: {
    id: string;
    status?: string;
    expires_at?: string;
  };
  access_token?: string;
  refresh_token?: string;
};

export type AgentAuthClientOptions = {
  apiUrl: string;
  accessToken?: string;
  fetcher?: typeof fetch;
};

export class AgentAuthClient {
  private apiUrl: string;
  private accessToken?: string;
  private fetcher: typeof fetch;

  constructor(options: AgentAuthClientOptions) {
    this.apiUrl = options.apiUrl.replace(/\/$/, "");
    this.accessToken = options.accessToken;
    this.fetcher = options.fetcher ?? fetch;
  }

  setAccessToken(token: string | undefined): void {
    this.accessToken = token;
  }

  async signup(input: SignupRequest): Promise<AuthResult> {
    return this.request<AuthResult>("POST", "/auth/signup", input);
  }

  async login(input: LoginRequest): Promise<AuthResult> {
    return this.request<AuthResult>("POST", "/auth/login", input);
  }

  async logout(session_id?: string): Promise<{ ok: boolean }> {
    return this.request<{ ok: boolean }>("POST", "/auth/logout", {
      session_id
    });
  }

  async getSession(): Promise<unknown> {
    return this.request("GET", "/auth/session");
  }

  async createMagicLink(input: MagicLinkRequest): Promise<unknown> {
    return this.request("POST", "/auth/magic-link", input);
  }

  async verifyMagicLink(token: string): Promise<AuthResult> {
    return this.request<AuthResult>("POST", "/auth/magic-link/verify", {
      token
    });
  }

  async getUser(identityId: string): Promise<unknown> {
    return this.request("GET", `/auth/users/${identityId}`);
  }

  async freezeUser(identityId: string, reason?: string): Promise<{ ok: boolean }> {
    return this.request<{ ok: boolean }>(
      "POST",
      `/auth/users/${identityId}/freeze`,
      { reason }
    );
  }

  async getValidationReports(targetRef: string): Promise<unknown> {
    return this.request("GET", `/auth/reports/${targetRef}`);
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown
  ): Promise<T> {
    const response = await this.fetcher(`${this.apiUrl}${path}`, {
      method,
      headers: {
        "content-type": "application/json",
        ...(this.accessToken
          ? { authorization: `Bearer ${this.accessToken}` }
          : {})
      },
      body: body ? JSON.stringify(body) : undefined
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Agent-Auth request failed: ${response.status} ${text}`);
    }

    return response.json() as Promise<T>;
  }
}
