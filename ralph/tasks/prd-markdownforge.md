# PRD: MarkdownForge

## Introduction

MarkdownForge is a Git-backed collaborative Markdown platform that lets small teams write, edit, and version Markdown documents through both a web UI and standard Git workflows. Every document lives in a bare Git repository on the server. Users edit in a CodeMirror 6 editor with live Markdown preview, collaborate in real time via Y.js CRDTs, and can clone/push/pull over HTTPS using personal access tokens. The platform targets 100-500 users on a single server.

The tech stack is: Rails 8.1.2, Inertia.js + Vue 3 + Nuxt UI 3, PostgreSQL 18, Rugged (libgit2), Y.js + y-rb + Action Cable (Solid Cable), CodeMirror 6, GoodJob, Solid Cache, Grover (PDF), Devise, Nginx + git-http-backend, Kamal 2.

## Goals

- Provide a web-based Markdown editor with live preview and Git-backed versioning for every save
- Enable real-time collaborative editing so multiple users can work on the same document simultaneously
- Support standard Git workflows (clone, fetch, push) over HTTPS so users can work with any Git client
- Manage team access with project memberships (owner/editor roles) and personal access tokens for Git auth
- Export documents as PDF or downloadable Markdown files
- Deploy the entire platform to a single server with Kamal 2
- Run the full development environment with a single command (`mise run dev`)

## User Stories

---

### Phase 1: Development Environment & Project Scaffolding

---

### US-001: Scaffold Rails application with core dependencies
**Description:** As a developer, I need the Rails 8.1.2 application scaffolded with all core gems and JS packages so that subsequent stories have a working foundation.

**Acceptance Criteria:**
- [ ] Rails 8.1.2 app created with PostgreSQL adapter
- [ ] Gemfile includes: `devise`, `inertia_rails`, `vite_rails`, `rugged`, `good_job`, `grover`, `commonmarker`, `solid_cache`, `solid_cable`, `y-rb`
- [ ] `package.json` includes: `@inertiajs/vue3`, `vue`, `@nuxt/ui-vue`, `@iconify-json/heroicons`, `@iconify-json/lucide`, `codemirror`, `@codemirror/lang-markdown`, `yjs`, `y-codemirror.next`, `markdown-it`, `vite`, `@vitejs/plugin-vue`, `vite-plugin-ruby`, `tailwindcss`, `@actioncable/core`
- [ ] `package.json` devDependencies include: `oxlint`, `oxfmt`
- [ ] Yarn 4.12.0 configured as package manager via `packageManager` field
- [ ] `bundle install` and `yarn install` succeed without errors

### US-002: Configure Vite with Nuxt UI and Tailwind CSS 4
**Description:** As a developer, I need Vite configured with the Vue plugin, Nuxt UI plugin, and Tailwind CSS 4 so that the frontend build pipeline works.

**Acceptance Criteria:**
- [ ] `vite.config.js` registers `vue()`, `ViteRuby()`, and `ui()` plugins with primary color `blue` and neutral `slate`
- [ ] `app/javascript/css/application.css` imports `tailwindcss` and `@nuxt/ui-vue/theme.css` with `@source` directive pointing to `../**/*.{vue,js,ts}`
- [ ] `app/javascript/entrypoints/application.js` sets up Inertia with `nuxtUI` plugin and page glob resolution
- [ ] `@` alias resolves to `/app/javascript`
- [ ] `yarn vite dev` starts without errors
- [ ] Verify Nuxt UI components render in browser

### US-003: Configure linting and formatting
**Description:** As a developer, I need Rubocop, Oxlint, and oxfmt configured so that `mise run lint` checks all code.

**Acceptance Criteria:**
- [ ] `.rubocop.yml` requires `rubocop-rails`, `rubocop-minitest`, `rubocop-performance`; targets Ruby 3.4; disables `Style/Documentation`; sets line length to 120 and method length to 20
- [ ] `.oxlintrc.json` warns on `no-unused-vars` and `no-console`, errors on `eqeqeq`
- [ ] `.oxfmt.json` configured with `printWidth: 100`, `semi: false`, `singleQuote: true`, `trailingComma: all`, Tailwind CSS class sorting enabled
- [ ] `package.json` scripts: `lint` runs oxlint, `format` runs oxfmt `--write`, `format:check` runs oxfmt `--check`
- [ ] `mise run lint` executes Rubocop, oxfmt check, and oxlint in sequence (continues on failure with `set +e`)
- [ ] All linters pass on the scaffolded codebase

### US-004: Configure mise and Docker Compose for development
**Description:** As a developer, I need `mise run dev` to start the entire development environment (Docker services, dependency install, database prep, and Foreman processes) with a single command.

**Acceptance Criteria:**
- [ ] `.mise.toml` specifies `node = "25.2.1"`, `ruby = "3.4.7"`, `yarn = "4.12.0"`
- [ ] `.mise.toml` defines tasks: `docker:start`, `docker:stop`, `deps`, `deps:ruby`, `deps:js`, `db:prepare`, `lint`, `test`, `dev`
- [ ] `dev-docker-compose.yml` defines `postgres` (postgres:18-alpine, port 5432, healthcheck) and `chromium` (browserless/chrome, port 3333:3000) services with a `pgdata` volume
- [ ] `Procfile.dev` starts `web` (Rails on port 3000), `js` (Vite dev), and `jobs` (GoodJob)
- [ ] `mise run dev` starts Docker, installs deps, prepares DB, launches Foreman processes
- [ ] Ctrl+C triggers `docker compose down` via SIGINT/SIGTERM trap
- [ ] `mise run test` runs `CI=1 bundle exec rails test`

### US-005: Create database schema
**Description:** As a developer, I need the database tables created so that models can be built on top of them.

**Acceptance Criteria:**
- [ ] Migration creates `users` table: `name` (string, not null), `email` (string, not null, unique index), `encrypted_password` (string, not null), `admin` (boolean, default false), timestamps
- [ ] Migration creates `personal_access_tokens` table: `user_id` (references, not null, FK), `name` (string, not null), `token_digest` (string, not null, unique index), `token_prefix` (string, limit 8), `last_used_at` (datetime), `expires_at` (datetime), `revoked_at` (datetime), timestamps
- [ ] Migration creates `projects` table: `name` (string, not null), `slug` (string, not null, unique index), `uuid` (uuid, not null, default `gen_random_uuid()`, unique index), `owner_id` (references users, not null, FK), timestamps
- [ ] Migration creates `project_memberships` table: `user_id` (references, not null, FK), `project_id` (references, not null, FK), `role` (string, not null, default `editor`), timestamps, unique composite index on `[user_id, project_id]`
- [ ] Migration creates `documents` table: `project_id` (references, not null, FK), `path` (string, not null), `last_commit_sha` (string), `last_modified_at` (datetime), timestamps, unique composite index on `[project_id, path]`
- [ ] `rails db:migrate` runs without errors
- [ ] `rails db:rollback` and `rails db:migrate` are idempotent

---

### Phase 2: Authentication & User Management

---

### US-006: Set up Devise authentication
**Description:** As a user, I want to sign up, log in, and log out so that my work is associated with my account.

**Acceptance Criteria:**
- [ ] Devise installed and configured for the `User` model with database_authenticatable, registerable, recoverable, rememberable, and validatable modules
- [ ] Sign up page collects name, email, and password
- [ ] Login page accepts email and password
- [ ] Logout link (`DELETE /logout`) ends the session
- [ ] Unauthenticated requests redirect to the login page
- [ ] All auth pages use Inertia + Vue + Nuxt UI components
- [ ] Verify sign up, login, and logout flows work in browser

### US-007: Create AppLayout with navigation
**Description:** As a user, I want a consistent app layout with navigation so I can move between projects, settings, and tokens.

**Acceptance Criteria:**
- [ ] `app/javascript/layouts/AppLayout.vue` renders a header with: app name ("MarkdownForge") linking to `/projects`, current user name, "Tokens" button linking to `/settings/tokens`, "Settings" button linking to `/settings`, "Log out" button (DELETE to `/logout`)
- [ ] Header uses `UContainer`, `UButton`, and `UBadge` components
- [ ] Main content area wrapped in `UContainer` with `py-8`
- [ ] `UNotifications` component rendered for toast messages
- [ ] Dark mode supported (bg-gray-50/bg-gray-950 backgrounds, border colors)
- [ ] Layout is the default for all Inertia pages
- [ ] Verify layout renders correctly in browser

### US-008: Build PersonalAccessToken model
**Description:** As a developer, I need the PAT model so that users can authenticate Git operations.

**Acceptance Criteria:**
- [ ] `PersonalAccessToken` model belongs to `User`, uses `has_secure_token :token`
- [ ] `before_create` callback sets `token_digest` (SHA-256 hex of `token`) and `token_prefix` (first 8 chars of `token`)
- [ ] `active` scope returns tokens where `revoked_at` is nil and `expires_at` is null or in the future
- [ ] `self.authenticate(plain_token)` computes SHA-256 digest and queries `active` scope by `token_digest`
- [ ] `revoke!` sets `revoked_at` to `Time.current`
- [ ] Plain token is accessible only during creation (never stored)
- [ ] Minitest: test token creation stores digest but not plain token
- [ ] Minitest: test `authenticate` returns the PAT for valid tokens and nil for revoked/expired tokens

### US-009: Token management UI
**Description:** As a user, I want to create, view, and revoke personal access tokens so that I can authenticate Git operations.

**Acceptance Criteria:**
- [ ] `GET /settings/tokens` renders a page listing active tokens with columns: Name, Token (prefix + masked), Last Used, and a Revoke button
- [ ] "New Token" button opens a `UModal` with a name input field
- [ ] `POST /settings/tokens` creates a token and redirects back with the plain token displayed once in a `UAlert` (warning color, "copy it now, it won't be shown again")
- [ ] `DELETE /settings/tokens/:id` revokes the token and shows a success toast
- [ ] Token prefix displayed as `<prefix>........` in a monospace `<code>` tag
- [ ] Verify create, display, and revoke flows in browser

---

### Phase 3: Project Management

---

### US-010: Project model and associations
**Description:** As a developer, I need the Project model with ownership and membership associations.

**Acceptance Criteria:**
- [ ] `Project` model has validations: `name` presence, `slug` presence and uniqueness
- [ ] `Project` belongs to `owner` (class: `User`)
- [ ] `Project` has many `memberships` (class: `ProjectMembership`) and has many `users` through `memberships`
- [ ] `User` has many `owned_projects` (class: `Project`, FK: `owner_id`) and has many `projects` through `memberships`
- [ ] `ProjectMembership` model validates `role` inclusion in `%w[owner editor]`
- [ ] `ProjectMembership` validates uniqueness of `user_id` scoped to `project_id`
- [ ] Minitest: test associations and validations

### US-011: Project CRUD with UI
**Description:** As a user, I want to create and view projects so that I can organize my Markdown documents.

**Acceptance Criteria:**
- [ ] `GET /projects` lists current user's projects (ordered by `updated_at` desc), each displayed as a `UCard` showing project name, owner name, updated_at, and user's role as a `UBadge`
- [ ] Empty state shows a `UAlert` with "No projects yet" message
- [ ] "New Project" button opens a `UModal` with a name input
- [ ] `POST /projects` creates the project, generates a slug from the name via `parameterize`, initializes a bare Git repo via `GitService.init_repo`, creates an `owner` membership for the current user, and redirects to the project show page
- [ ] `GET /projects/:slug` shows the project name, role badge, clone URL (`<base_url>/git/<slug>.git`), file list, and a "New File" button
- [ ] Empty file list shows a `UAlert` with "No files yet" message
- [ ] Verify project creation and listing in browser

---

### Phase 4: Git Repository Management

---

### US-012: Implement GitService
**Description:** As a developer, I need a service object that wraps all Rugged operations so that controllers and jobs never shell out to `git`.

**Acceptance Criteria:**
- [ ] `GitService` is a class in `app/services/git_service.rb`
- [ ] `REPOS_ROOT` reads from `Rails.configuration.repos_root`
- [ ] `repo_path(project)` returns `"#{REPOS_ROOT}/#{project.uuid}.git"`
- [ ] `init_repo(project)` calls `Rugged::Repository.init_at(path, :bare)`
- [ ] `with_repo_lock(project)` acquires an exclusive file lock (`File.flock(File::LOCK_EX)`) on `"#{repo_path}.lock"` and yields
- [ ] `read_file(project, path, ref: "HEAD")` returns file content at the given ref; raises `FileNotFoundError` if the path doesn't exist in the tree
- [ ] `commit_file(project:, path:, content:, user:, message:, base_sha: nil)` writes a blob, updates the index, creates a commit with author/committer from user, and updates HEAD; raises `StaleCommitError` if `base_sha` is provided and doesn't match current HEAD
- [ ] `list_files(project, ref: "HEAD")` returns an array of file paths by walking blobs
- [ ] `file_history(project, path)` returns an array of commits that touched the given path (sha, message, author, time)
- [ ] `delete_file(project:, path:, user:, message:)` removes a file from the index and creates a commit
- [ ] `file_content_at(project, path, sha)` returns file content at a specific commit
- [ ] All write operations use `with_repo_lock`
- [ ] Custom errors: `StaleCommitError`, `FileNotFoundError`
- [ ] Minitest: test init, write, read, list, delete, history, stale commit detection

### US-013: Configure repos_root in Rails
**Description:** As a developer, I need the Git repos root path configurable so it can differ between development and production.

**Acceptance Criteria:**
- [ ] `config/application.rb` or an initializer sets `config.repos_root` from `ENV["GIT_REPOS_ROOT"]` with a default of `Rails.root.join("tmp/repos")`
- [ ] Development uses `tmp/repos` (gitignored)
- [ ] Production uses `/var/repos` (set via Kamal env)
- [ ] `.gitignore` includes `tmp/repos/`

---

### Phase 5: Web-Based File Editing

---

### US-014: File CRUD controller and routes
**Description:** As a user, I want to create, view, edit, and delete Markdown files in a project through the web UI.

**Acceptance Criteria:**
- [ ] Routes: `GET /projects/:slug/files/:path` (show), `GET /projects/:slug/files/:path/edit` (edit form), `PATCH /projects/:slug/files/:path` (update/commit), `POST /projects/:slug/files` (create), `DELETE /projects/:slug/files/:path` (destroy)
- [ ] `FilesController` uses `before_action :set_project` scoped to `current_user.projects`
- [ ] `show` action reads file content and HEAD SHA via GitService, renders `Files/Show` Inertia page
- [ ] `edit` action reads file content and HEAD SHA, renders `Files/Edit` Inertia page
- [ ] `update` action commits via `GitService.commit_file` with `base_sha` for optimistic concurrency; on `StaleCommitError`, redirects back with an alert
- [ ] `create` action commits a new file with default content `# <filename>\n`
- [ ] `destroy` action deletes the file via `GitService.delete_file` and redirects to project show
- [ ] Minitest: test each action (create, show, edit, update, destroy, stale commit redirect)

### US-015: Markdown editor with CodeMirror 6
**Description:** As a user, I want a CodeMirror 6 editor for writing Markdown so that I get syntax highlighting and a good editing experience.

**Acceptance Criteria:**
- [ ] `Files/Edit.vue` page renders a CodeMirror 6 editor with `basicSetup` and `markdown()` language extension
- [ ] Editor fills available space with a border and rounded corners
- [ ] A "Save" button sends the editor content to `PATCH /projects/:slug/files/:path` with a commit message
- [ ] Connection status badge shows "connected" (green) or "disconnected" (red) using `UBadge`
- [ ] `base_commit_sha` is sent with the save request for optimistic concurrency
- [ ] Verify editor loads, accepts input, and saves in browser

### US-016: Markdown preview component
**Description:** As a user, I want to preview rendered Markdown alongside the editor so that I can see how my document will look.

**Acceptance Criteria:**
- [ ] `MarkdownPreview.vue` component accepts a `content` string prop
- [ ] Uses `markdown-it` with `html: false`, `linkify: true`, `typographer: true`
- [ ] Renders HTML inside a `div` with Tailwind `prose prose-sm max-w-none dark:prose-invert` classes
- [ ] `Files/Show.vue` page displays the rendered preview by default
- [ ] `Files/Edit.vue` page provides a split-pane or toggle between editor and preview
- [ ] Verify preview renders headings, lists, code blocks, links, and blockquotes in browser

### US-017: File show page
**Description:** As a user, I want to view a Markdown file with rendered preview and action buttons.

**Acceptance Criteria:**
- [ ] `Files/Show.vue` displays the file path as a heading
- [ ] Rendered Markdown preview shown via `MarkdownPreview` component
- [ ] Action buttons: "Edit" (links to edit page), "History" (links to history page), "Download MD", "Download PDF"
- [ ] "Download MD" triggers `GET /projects/:slug/files/:path/download.md` which sends the raw Markdown as an attachment
- [ ] "Download PDF" triggers `POST /projects/:slug/files/:path/download.pdf` which enqueues a `PdfExportJob` and shows a notice
- [ ] Verify file show page renders correctly in browser

---

### Phase 6: File History & Versioning

---

### US-018: File history controller and UI
**Description:** As a user, I want to see the commit history of a file so that I can track changes over time.

**Acceptance Criteria:**
- [ ] `GET /projects/:slug/files/:path/history` renders `Files/History.vue` with a `UTable` showing columns: Commit (SHA badge, first 8 chars), Message, Author, Date, and a "View" action button
- [ ] Each row links to `GET /projects/:slug/files/:path/history/:sha`
- [ ] Empty history shows a `UAlert` with "No history" message
- [ ] "Back to file" button links to the file show page
- [ ] `FileHistoryController` is scoped to `current_user.projects`
- [ ] Minitest: test index and show actions
- [ ] Verify history table and version viewing in browser

### US-019: View file at specific commit
**Description:** As a user, I want to view a file's content at a specific commit so that I can see what it looked like in the past.

**Acceptance Criteria:**
- [ ] `Files/HistoryShow.vue` displays the commit SHA, and rendered Markdown preview of the file at that commit
- [ ] "Back to history" button links to the file history page
- [ ] Uses `GitService.file_content_at` to read the file at the given SHA
- [ ] Verify historical file content renders correctly in browser

---

### Phase 7: Real-Time Collaborative Editing

---

### US-020: Action Cable setup with Solid Cable
**Description:** As a developer, I need Action Cable configured with Solid Cable (PostgreSQL-backed) so that WebSocket connections work.

**Acceptance Criteria:**
- [ ] `config/cable.yml` configured to use `solid_cable` adapter in development and production
- [ ] Solid Cable migration run (uses the `cable` database or dedicated table in the primary database)
- [ ] `ApplicationCable::Connection` authenticates the user from the session (Devise `warden`)
- [ ] WebSocket endpoint available at `/cable`
- [ ] Minitest: test that unauthenticated connections are rejected

### US-021: DocumentChannel for Y.js sync
**Description:** As a developer, I need an Action Cable channel that syncs Y.js document state between connected clients.

**Acceptance Criteria:**
- [ ] `DocumentChannel` subscribes with `project_id` and `file_path` params
- [ ] On subscribe: rejects if user lacks project membership; loads or initializes Y.js doc state from Solid Cache (key: `ydoc:<project_id>:<file_path>`); transmits initial state as Base64-encoded sync message
- [ ] On `update` message: decodes Base64 update, applies it to the cached Y.Doc via `y-rb`, writes merged state to cache (2-hour TTL), broadcasts update to all subscribers (excluding sender via `sender` field), and enqueues `FlushYdocToGitJob` with 30-second delay
- [ ] On `save` message: immediately enqueues `FlushYdocToGitJob`
- [ ] On unsubscribe: enqueues `FlushYdocToGitJob` with 5-second delay
- [ ] `load_or_init_ydoc`: reads from cache; if miss, reads file from Git (or empty string if not found), creates a `Y::Doc`, inserts content into `getText("content")`, caches the state
- [ ] Minitest: test subscribe/reject, state initialization, update broadcast

### US-022: FlushYdocToGitJob
**Description:** As a developer, I need a background job that flushes the Y.js document state to a Git commit so that collaborative edits are persisted.

**Acceptance Criteria:**
- [ ] `FlushYdocToGitJob` reads Y.js state from cache, extracts text content, and commits to Git via `GitService.commit_file`
- [ ] Skips commit if content matches existing file content (no-op)
- [ ] Uses `good_job_control_concurrency_with` with key `flush_ydoc:<project_id>:<file_path>` and `total_limit: 1` to prevent concurrent flushes of the same file
- [ ] Commit message: "Auto-save <file_path>"
- [ ] Minitest: test flush creates commit, skip on no change, concurrency key

### US-023: Collaborative editor frontend
**Description:** As a user, I want to edit a Markdown file collaboratively in real time with other users.

**Acceptance Criteria:**
- [ ] `Files/Edit.vue` creates a `Y.Doc`, gets `getText("content")`, and sets up `Y.UndoManager`
- [ ] Action Cable subscription created for `DocumentChannel` with `project_id` and `file_path`
- [ ] On `sync` message: applies Base64-decoded state to Y.Doc and sets status to "connected"
- [ ] On `update` message from other users: applies Base64-decoded update to Y.Doc
- [ ] Local Y.Doc updates (not from remote) are sent to the channel as Base64-encoded update messages
- [ ] CodeMirror 6 editor uses `yCollab(ytext, null, { undoManager })` extension for collaborative editing
- [ ] Connection status badge updates between "connecting", "connected", "disconnected"
- [ ] "Save" button sends `{ type: "save" }` to the channel and shows a toast
- [ ] On unmount: unsubscribes from channel, destroys editor view and Y.Doc
- [ ] Verify two browser tabs can collaboratively edit the same file in real time

---

### Phase 8: Git Smart HTTP Access

---

### US-024: Git HTTP auth endpoint
**Description:** As a developer, I need a Rails endpoint that Nginx calls to authorize Git HTTP requests using personal access tokens.

**Acceptance Criteria:**
- [ ] `Api::Git::AuthorizeController#show` at `GET /api/git/authorize`
- [ ] Skips Devise `authenticate_user!`
- [ ] Extracts Basic Auth credentials from `Authorization` header; returns 401 if missing or not Basic
- [ ] Decodes Base64 credentials to get email and token
- [ ] Finds user by email and authenticates token via `PersonalAccessToken.authenticate`; returns 401 if either fails
- [ ] Touches `last_used_at` on the PAT
- [ ] Extracts project slug from `X-Original-URI` header (pattern: `/git/<slug>.git/...`)
- [ ] Checks user has a membership on the project; returns 403 if not
- [ ] For push operations (URI contains `git-receive-pack`): checks membership role is `owner` or `editor`; returns 403 if not
- [ ] Returns 200 on success
- [ ] Minitest: test auth success, invalid token, no membership, push permission check

### US-025: Nginx configuration for Git Smart HTTP
**Description:** As a developer, I need Nginx configured to serve Git Smart HTTP via `git-http-backend` with auth delegated to Rails.

**Acceptance Criteria:**
- [ ] Nginx config file at `config/nginx/app.conf`
- [ ] Upstream `rails_app` on `127.0.0.1:3000`
- [ ] `location /` proxies to Rails with standard headers (Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto)
- [ ] `location /cable` proxies with WebSocket upgrade headers (HTTP/1.1, Upgrade, Connection)
- [ ] `location ~ ^/git/(?<repo_path>.+)` uses `auth_request /internal/git/authorize`, passes to `fcgiwrap` socket with `git-http-backend`, sets `GIT_PROJECT_ROOT` to `/var/repos` and `GIT_HTTP_EXPORT_ALL`, `client_max_body_size 50m`
- [ ] `location = /internal/git/authorize` is internal, proxies to Rails `/api/git/authorize` with `X-Original-URI` and `Authorization` headers, no request body

---

### Phase 9: PDF Export

---

### US-026: Configure Grover for PDF generation
**Description:** As a developer, I need Grover configured to generate PDFs from Markdown content rendered as HTML.

**Acceptance Criteria:**
- [ ] `config/initializers/grover.rb` sets format A4, margins (top/bottom 1cm, left/right 1.5cm), `print_background: true`
- [ ] Development config includes `--no-sandbox` launch arg and `browser_ws_endpoint` pointing to `ws://localhost:3333` (the Docker Chromium container)

### US-027: PdfExportJob with notification
**Description:** As a user, I want to export a Markdown file as a PDF and be notified when it's ready.

**Acceptance Criteria:**
- [ ] `PdfExportJob` queued on `:pdf_export` queue
- [ ] Reads file content from Git, renders Markdown to HTML using `CommonMarker.render_html` with table, strikethrough, and tasklist extensions
- [ ] Wraps HTML in a styled document template (system fonts, prose styling for h1/h2/code/pre/blockquote/table/img)
- [ ] Generates PDF via `Grover.new(html).to_pdf`
- [ ] Uploads PDF to Active Storage as a blob with filename `<basename>.pdf`
- [ ] Broadcasts a `pdf_ready` notification to `user:<user_id>:notifications` via Action Cable with filename and download URL
- [ ] Minitest: test job creates a PDF blob and broadcasts notification

### US-028: PDF notification on the frontend
**Description:** As a user, I want to receive a toast notification with a download link when my PDF is ready.

**Acceptance Criteria:**
- [ ] Frontend subscribes to `user:<user_id>:notifications` Action Cable channel
- [ ] On `pdf_ready` message: shows a toast notification with the filename and a download link
- [ ] Verify PDF export triggers notification and download works in browser

---

### Phase 10: Background Jobs & Maintenance

---

### US-029: Configure GoodJob
**Description:** As a developer, I need GoodJob configured as the Active Job backend with async execution, queue configuration, and cron jobs.

**Acceptance Criteria:**
- [ ] `config/application.rb` sets `config.active_job.queue_adapter = :good_job`
- [ ] GoodJob initializer configures: `execution_mode: :async`, queues `default:5;pdf_export:2`, `max_threads: 7`, `poll_interval: 5`, `shutdown_timeout: 25`, `enable_cron: true`
- [ ] Cron jobs: `cleanup_expired_tokens` runs daily at 3 AM, `cleanup_stale_ydocs` runs every 15 minutes
- [ ] GoodJob dashboard mounted at `/good_job` behind `authenticate :user, ->(user) { user.admin? }`
- [ ] Minitest: test that jobs can be enqueued

### US-030: CleanupExpiredTokensJob
**Description:** As a developer, I need a job that cleans up expired and long-revoked tokens.

**Acceptance Criteria:**
- [ ] `CleanupExpiredTokensJob` deletes tokens where `expires_at` is in the past or `revoked_at` is older than 30 days
- [ ] Runs daily at 3 AM via GoodJob cron
- [ ] Minitest: test that expired and old revoked tokens are deleted, active tokens are kept

### US-031: CleanupStaleYdocsJob
**Description:** As a developer, I need a job that flushes and cleans up Y.js documents with no active connections.

**Acceptance Criteria:**
- [ ] `CleanupStaleYdocsJob` checks for cached Y.doc states with no active Action Cable subscribers
- [ ] Flushes any remaining state to Git before clearing from cache
- [ ] Runs every 15 minutes via GoodJob cron
- [ ] Minitest: test cleanup of stale documents

---

### Phase 11: Deployment

---

### US-032: Kamal deployment configuration
**Description:** As a developer, I need Kamal 2 configured so that the app can be deployed to a single server.

**Acceptance Criteria:**
- [ ] `config/deploy.yml` defines service `mdforge` with image registry on `ghcr.io`
- [ ] `web` server role: hosts list, 2GB memory limit, volume mount `/var/repos:/var/repos`
- [ ] `jobs` server role: runs `bundle exec good_job start`, 1GB memory limit, same volume mount
- [ ] Proxy configured with SSL, app port 3000
- [ ] Builder targets `amd64` architecture
- [ ] Environment variables: clear (`RAILS_ENV`, `RAILS_LOG_TO_STDOUT`, `GOOD_JOB_EXECUTION_MODE: external`, `GIT_REPOS_ROOT: /var/repos`), secret (`RAILS_MASTER_KEY`, `DATABASE_URL`, `CABLE_DATABASE_URL`, `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`)
- [ ] Accessories: `postgres` (postgres:18-alpine, bound to 127.0.0.1:5432, pgdata volume), `nginx` (nginx:alpine, port 443, config file mount, repos volume read-only, SSL certs volume read-only)

### US-033: Production Dockerfile
**Description:** As a developer, I need a production Dockerfile that builds the Rails app with all dependencies.

**Acceptance Criteria:**
- [ ] Multi-stage build: build stage installs Ruby gems, Node/Yarn, and compiles assets; runtime stage is minimal
- [ ] Runtime stage includes `libgit2` for Rugged
- [ ] Assets precompiled with `SECRET_KEY_BASE_DUMMY=1 rails assets:precompile`
- [ ] Final image runs as non-root user
- [ ] `kamal setup` succeeds with the Dockerfile

---

## Functional Requirements

- FR-1: All access requires authentication. Unauthenticated requests to any route (except login/signup) must redirect to the login page.
- FR-2: Every project has exactly one `owner` and zero or more `editor` members. Only `owner` and `editor` roles exist.
- FR-3: Only project members can view project files. Non-members receive a 404.
- FR-4: Only `owner` and `editor` roles can push via Git. All members can clone and pull.
- FR-5: Every file modification (create, edit, delete) through the web UI results in a Git commit in the project's bare repository.
- FR-6: The web editor sends a `base_commit_sha` with save requests. If HEAD has advanced since the user loaded the editor, the save is rejected with a "stale commit" error.
- FR-7: Real-time collaborative editing uses Y.js CRDTs. Multiple users editing the same file see each other's changes without conflicts.
- FR-8: Y.js document state is cached in Solid Cache with a 2-hour TTL. Edits are flushed to Git as auto-save commits with 30-second debounce.
- FR-9: When all editors disconnect from a document, the final Y.js state is flushed to Git within 5 seconds.
- FR-10: Personal access tokens are stored as SHA-256 digests. The plain token is displayed once at creation and never retrievable again.
- FR-11: Git Smart HTTP is served via Nginx + `git-http-backend` + fcgiwrap. Auth is delegated to Rails via `auth_request`.
- FR-12: PDF export runs asynchronously via GoodJob. The user is notified via Action Cable when the PDF is ready for download.
- FR-13: PDF rendering uses Grover (Puppeteer/Chromium). Concurrency is limited to 2 simultaneous renders via GoodJob concurrency control.
- FR-14: The GoodJob dashboard is accessible only to admin users at `/good_job`.
- FR-15: All Rugged write operations acquire an exclusive file lock to prevent concurrent writes to the same repository.

## Non-Goals

- No public (unauthenticated) project access
- No viewer (read-only) role beyond owner/editor
- No custom roles or RBAC
- No file upload support (images, attachments) in this version
- No Markdown extensions beyond standard CommonMark + tables + strikethrough + tasklists
- No folder/directory management UI (files are flat paths)
- No merge conflict resolution UI in the web editor
- No branch support (all operations on HEAD/main only)
- No project deletion (admin-only manual process for now)
- No email notifications
- No search across projects or files
- No commenting or annotations on documents
- No multi-server deployment (single server only)

## Design Considerations

- All UI components come from Nuxt UI 3 (`@nuxt/ui-vue`): `UButton`, `UCard`, `UTable`, `UModal`, `UInput`, `UFormField`, `UBadge`, `UAlert`, `UNotifications`, `UContainer`
- Tailwind CSS 4 with CSS-first configuration (no `tailwind.config.js`)
- Dark mode supported via Nuxt UI's `colorMode` option
- Icon sets: `@iconify-json/heroicons` and `@iconify-json/lucide`
- Layout: fixed header (h-14) + scrollable main content
- Editor: CodeMirror 6 in a bordered rounded container, full width
- Preview: Tailwind Typography (`prose`) classes for rendered Markdown

## Technical Considerations

- **Rugged (libgit2):** All Git operations go through Rugged. Never shell out to `git`. Requires `libgit2` installed on the system (and in the Docker image).
- **y-rb gem:** Ruby bindings for Yrs (Rust Y.js implementation). Less mature than JS Y.js but functional for server-side state merging.
- **Solid Cache & Solid Cable:** PostgreSQL-backed cache and pub/sub. No Redis dependency. Requires separate database connections or dedicated tables.
- **File locking:** `File.flock(File::LOCK_EX)` works for a single server. For multi-server, switch to PostgreSQL advisory locks (out of scope).
- **Vite + Inertia:** Vite dev server runs on a separate port. In production, assets are precompiled. Inertia handles SPA-like navigation without a separate API.
- **oxfmt:** Formatter for JS/Vue with Tailwind CSS class sorting. Complements oxlint (linter). Both are fast Rust-based tools.
- **Rate limiting:** Add `Rack::Attack` to rate-limit the Git auth endpoint (recommended but not a blocker for initial release).

## Success Metrics

- A new developer can clone the repo and have the full dev environment running with `mise install && mise run dev` in under 5 minutes
- Users can create a project, add a Markdown file, edit it, and see the rendered preview within 60 seconds of first login
- Two users can simultaneously edit the same document and see each other's changes within 1 second
- Git clone/push/pull over HTTPS works with any standard Git client using PAT authentication
- PDF export completes within 10 seconds for documents under 50 pages
- All Minitest tests pass (`mise run test`)
- All linters pass (`mise run lint`)
- The application deploys to a single server via `kamal setup` and `kamal deploy`

## Open Questions

1. Should there be a project settings page where owners can manage members (invite/remove)? The architecture doc mentions memberships but no invite flow UI is detailed.
    Answer: Yes, there should be a project settings page where owners can manage members (invite/remove).
2. Should the editor auto-save on a timer (e.g., every 60 seconds of inactivity) in addition to the manual save button and the Y.js flush mechanism?
    Answer: Yes, the editor should auto-save on a timer (e.g., every 60 seconds of inactivity) in addition to the manual save button and the Y.js flush mechanism.
3. What should happen when a user pushes via Git while someone is editing the same file in the web UI? The Y.js state and Git state could diverge.
    Answer: The user on UI should be notified that the file has been changed by another user and they should refresh the page to get the latest version.
4. Should expired/revoked tokens show in the token management UI (greyed out) or be hidden entirely?
    Answer: Expired/revoked tokens should show in the token management UI (greyed out).
5. Is there a need for a user settings/profile page beyond token management (e.g., change name, change password)?
    Answer: Yes, there should be a user settings/profile page beyond token management (e.g., change name, change password).
6. Should the app support `Rack::Attack` rate limiting on the Git auth endpoint from day one, or defer to a later hardening phase?
    Answer: The app should use the Rails built-in rate limiting feature.
