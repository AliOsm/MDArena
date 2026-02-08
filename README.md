# MDArena

Collaborative Markdown editing, powered by Git. Edit together in real time, with every change backed by a full Git history.

MDArena gives teams a shared workspace for Markdown files where multiple people can edit simultaneously without conflicts. Under the hood, each project is a bare Git repository. You can edit through the web interface or clone with `git` and push changes from your terminal. Both workflows stay in sync.

## Table of Contents

- [Features](#features)
- [Roadmap](#roadmap)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Development](#development)
- [Testing](#testing)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
- [Deployment](#deployment)

## Features

**Real-time collaborative editing** -- Multiple users edit the same file simultaneously with live cursors and zero conflicts, powered by Y.js CRDTs.

**Git-backed versioning** -- Every save creates a Git commit. Browse full file history, view any past revision, and see who changed what.

**Clone over HTTPS** -- Each project is a standard Git repository. Clone it, edit locally with your favorite tools, and push changes back.

**Split-pane editor** -- Write Markdown on the left, see the rendered preview on the right. The editor uses CodeMirror 6 with syntax highlighting and collaborative cursor indicators.

**Project-based organization** -- Group files into projects. Invite team members as editors or owners. Each project gets its own Git repository and clone URL.

**Auto-save** -- Changes are automatically committed to Git after 60 seconds of inactivity. No work is lost even if you forget to save.

**Mobile-friendly** -- Responsive layout with a collapsible sidebar, stacking forms, and scrollable tables. The editor hides the preview pane on small screens to maximize editing space.

## Roadmap

Planned next features:

- **Delete projects** -- Allow project owners to delete a project and its bare Git repository (with a safety confirmation).
- **Inline highlights + comments** -- Highlight text ranges and start comment threads anchored to the selected content.
- **File-level comments** -- A general comment thread under each file (not tied to a specific highlight).
- **@mentions in comments** -- Mention project members with autocomplete and notifications.
- **Full-text search** -- Search across files in a project by filename and content.

## Architecture

```
Browser (Vue 3 + CodeMirror + Y.js)
    |
    |-- Inertia.js -------- Rails Controllers ------- PostgreSQL
    |                                                  (users, projects, memberships)
    |
    |-- Action Cable ------- DocumentChannel --------- Rails.cache
    |                                                  (Y.js CRDT state)
    |                                                       |
    |                                                  FlushYdocToGitJob
    |                                                       |
    |-- Git HTTP ---- Nginx ---- git-http-backend ---- Bare Git Repos
        (clone/push)                                   (tmp/repos/)
```

The application uses a hybrid storage model. PostgreSQL stores user accounts, projects, and memberships. Git repositories store all file content and history. The Rails cache holds active Y.js CRDT state during collaborative editing sessions, which gets periodically flushed to Git as commits.

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Ruby 3.4, JavaScript (ES modules) |
| Backend | Rails 8.1 |
| Frontend | Vue 3.5, Vite 6, Inertia.js |
| UI | Nuxt UI v4, Tailwind CSS 4 |
| Database | PostgreSQL 18 |
| Editor | CodeMirror 6 |
| Collaboration | Y.js CRDTs, y-codemirror.next |
| Real-time | Action Cable (Solid Cable adapter) |
| Git | Rugged (libgit2), Nginx + git-http-backend |
| Background jobs | GoodJob |
| Caching | Solid Cache (production), in-memory (development) |
| Auth | Devise |
| Deployment | Kamal, Docker |

## Getting Started

### Prerequisites

- [mise](https://mise.jdx.dev/) (manages Ruby, Node.js, and Yarn versions)
- [Docker](https://www.docker.com/) (for PostgreSQL and the Git HTTP server)
- libgit2 development headers (for the `rugged` gem)

On macOS:

```sh
brew install mise libgit2
```

### Setup

Clone the repository and run the full setup:

```sh
git clone <repo-url> md-arena
cd md-arena

# Install tool versions (Ruby 3.4.7, Node 25.2.1, Yarn 4.12.0)
mise install

# Start Docker services, install dependencies, prepare databases, and boot the app
mise run dev
```

This single command starts everything: PostgreSQL, the Git HTTP server (Nginx), the Rails server, the Vite dev server, and background jobs (GoodJob).

Once running, visit:

- **App**: http://localhost:3000
- **Rails server**: http://localhost:3001 (direct, bypasses Nginx)
- **Vite dev server**: http://localhost:3036

### Manual Setup

If you prefer to set things up step by step:

```sh
# Start Docker services (PostgreSQL + Git Nginx)
mise run docker:start

# Install dependencies
mise run deps

# Prepare the database
mise run db:prepare

# Start the development server
bin/dev
```

## Development

### Running Services

The development environment runs two processes via Foreman (`bin/dev`):

| Process | Port | Purpose |
|---|---|---|
| Rails server | 3001 | Backend API and Inertia page rendering |
| Vite dev server | 3036 | Frontend asset compilation with HMR |

By default, jobs run in-process in development (`GOOD_JOB_EXECUTION_MODE=async`). If you want an external worker, set `GOOD_JOB_EXECUTION_MODE=external` and run `bundle exec good_job start`.

Two Docker containers run alongside:

| Container | Port | Purpose |
|---|---|---|
| PostgreSQL 18 | 5432 | Primary, cable, and cache databases |
| Nginx + git-http-backend | 3000 | Git clone/push/pull over HTTPS |

### Databases

The app uses three PostgreSQL databases:

- **Primary** (`md_arena_development`) -- Users, projects, memberships
- **Cable** (`md_arena_development_cable`) -- Solid Cable message queue for Action Cable
- **Cache** (`md_arena_production_cache`) -- Solid Cache entries (production only)

### Useful Commands

```sh
# Start/stop Docker services
mise run docker:start
mise run docker:stop

# Install all dependencies
mise run deps

# Run all linters
mise run lint

# Run the test suite
mise run test

# Rails console
bin/rails console

# Database console
bin/rails dbconsole
```

### Code Quality

The project enforces consistent code style with three tools:

```sh
# Ruby linting (auto-fix with -A)
bundle exec rubocop
bundle exec rubocop -A

# JavaScript linting
yarn lint

# JavaScript formatting
yarn format:check
yarn format
```

RuboCop inherits from [rubocop-rails-omakase](https://github.com/rails/rubocop-rails-omakase). JavaScript uses [oxlint](https://oxc.rs/docs/guide/usage/linter) for linting and [oxfmt](https://oxc.rs/docs/guide/usage/formatter) for formatting.

## Testing

Tests use Minitest with parallel execution:

```sh
# Run unit and integration tests
bin/rails test

# Run system tests (requires Chrome)
bin/rails test:system

# Run everything
mise run test
```

Test coverage includes:

- **Models** -- User, Project, ProjectMembership validations and associations
- **Controllers** -- All routes including file CRUD, history, memberships, auth, settings, and Git authorization
- **Channels** -- Action Cable connection authentication and DocumentChannel message handling
- **Jobs** -- FlushYdocToGitJob and CleanupStaleYdocsJob
- **Services** -- GitService operations (init, read, write, delete, history, locking)

### CI

GitHub Actions runs four jobs on every pull request and push to `main`:

1. **scan_ruby** -- Brakeman (static security analysis) and bundler-audit (dependency vulnerabilities)
2. **lint** -- RuboCop with caching
3. **test** -- Unit and integration tests against PostgreSQL
4. **system-test** -- Browser tests with screenshot capture on failure

## Project Structure

```
app/
  channels/
    document_channel.rb       # Real-time collaborative editing via Y.js
  controllers/
    api/git/authorize_controller.rb  # Git HTTP authentication
    files_controller.rb              # File CRUD (reads/writes Git)
    file_history_controller.rb       # Git commit log browsing
    projects_controller.rb           # Project management
    project_memberships_controller.rb # Team member management
    settings/profile_controller.rb   # User profile settings
    users/sessions_controller.rb     # Devise sign in (Inertia)
    users/registrations_controller.rb # Devise sign up (Inertia)
  javascript/
    components/
      MarkdownPreview.vue     # Renders Markdown to HTML via markdown-it
    layouts/
      AppLayout.vue           # Main layout with sidebar navigation
      EditorLayout.vue        # Minimal full-screen layout for the editor
    pages/
      Auth/SignIn.vue          # Login page
      Auth/SignUp.vue          # Registration page
      Projects/Index.vue       # Project listing with search
      Projects/Show.vue        # File listing and clone URL
      Projects/Settings.vue    # Member management
      Settings/Profile.vue     # User profile form
      Files/Show.vue           # Read-only file view
      Files/Edit.vue           # Collaborative editor (CodeMirror + Y.js)
      Files/History.vue        # Git commit history
      Files/HistoryShow.vue    # File at a specific revision
    css/
      application.css          # Tailwind CSS + Nuxt UI imports
    entrypoints/
      application.js           # Inertia.js app initialization
  jobs/
    flush_ydoc_to_git_job.rb  # Commits Y.js state to Git
    cleanup_stale_ydocs_job.rb # Flushes inactive documents
  models/
    user.rb                   # Devise user with project associations
    project.rb                # Project with slug, UUID, and Git repo
    project_membership.rb     # Join table with owner/editor roles
  services/
    git_service.rb            # All Git operations via Rugged (libgit2)
config/
  deploy.yml                  # Kamal deployment configuration
  nginx/                      # Nginx configs for Git HTTP and proxying
  docker/                     # Dev Docker setup for Git Nginx
```

## How It Works

### Collaborative Editing

When a user opens a file in the editor:

1. The browser connects to the `DocumentChannel` via Action Cable (WebSocket).
2. The channel loads the Y.js CRDT state from the Rails cache, or initializes it from the Git repository if no cached state exists.
3. The initial state is sent to the client, where Y.js populates the CodeMirror editor.
4. As the user types, Y.js generates CRDT updates that are broadcast to all connected clients through the channel.
5. Remote updates are applied locally by Y.js, which merges them automatically without conflicts.
6. Each user's cursor position and selection are shared via the Y.js awareness protocol, rendered as colored indicators in other users' editors.
7. After 60 seconds of inactivity (or on manual save), a background job extracts the text from the Y.js document and commits it to the Git repository.

The Y.js CRDT layer means two users can type in the same paragraph at the same time and their edits will merge correctly. No manual conflict resolution is needed.

### Git Storage

Each project maps to a bare Git repository stored at `{repos_root}/{project.uuid}.git`. The UUID (not the slug) is used so that renaming a project does not require moving the repository on disk.

All file operations go through `GitService`, which uses the Rugged gem (libgit2 bindings) to manipulate blobs, trees, and commits directly on the bare repository. There is no working directory.

File-level locking via `flock` prevents race conditions when multiple processes write to the same repository simultaneously.

### Git HTTP Access

Users can clone and push to their projects over HTTPS:

```sh
git clone http://localhost:3000/git/my-project.git
```

When prompted, use your MDArena email as the username and your account password.

The Git HTTP flow works as follows:

1. The client sends a Git request with Basic Auth credentials.
2. Nginx intercepts the request and sends a subrequest to `/api/git/authorize`.
3. Rails validates the credentials and checks project membership.
4. On success, Rails returns the repository UUID in an `X-Repo-UUID` header.
5. Nginx proxies the request to `git-http-backend`, which serves the bare repository.

Push operations require the user to have an `owner` or `editor` role on the project.

### External Change Detection

The `DocumentChannel` checks the Git HEAD SHA every 10 seconds. If it detects that HEAD has changed (from a `git push` or another source), it invalidates the cached Y.js state and notifies all connected clients to reload the file. This keeps the web editor in sync with changes made outside the browser.

### Auto-Save and Cleanup

Two background jobs keep the system consistent:

- **FlushYdocToGitJob** -- Runs 30 seconds after the last edit (debounced) or 5 seconds after the last user disconnects. Extracts text from the cached Y.js document, compares it with the Git file content, and creates a commit if there are changes.

- **CleanupStaleYdocsJob** -- Runs every 15 minutes via cron. Finds Y.js documents in the cache that have no active WebSocket connections, flushes them to Git, and removes them from the cache.

## Deployment

The app deploys with [Kamal](https://kamal-deploy.org/) using Docker. The production image bundles Rails, Puma, Nginx, fcgiwrap, and git-http-backend into a single container.

### Production Architecture

Two containers run on the server:

- **web** -- Nginx (port 80) proxies to Puma (port 3000) for the Rails app, serves static assets, handles WebSocket upgrades for Action Cable, and routes Git HTTP requests through fcgiwrap to git-http-backend.
- **job** -- A dedicated GoodJob worker for background job processing.

Both containers share a `/var/repos` volume where bare Git repositories are stored.

### Environment Variables

| Variable | Purpose |
|---|---|
| `RAILS_MASTER_KEY` | Decrypts Rails credentials |
| `DATABASE_URL` | Primary PostgreSQL connection |
| `CABLE_DATABASE_URL` | Solid Cable database connection |
| `CACHE_DATABASE_URL` | Solid Cache database connection |
| `QUEUE_DATABASE_URL` | GoodJob queue database connection |
| `GIT_REPOS_ROOT` | Path to bare Git repositories (default: `/var/repos`) |

### Deploy

```sh
kamal setup    # First-time setup (provisions server, starts accessories)
kamal deploy   # Deploy a new version
kamal console  # Open a Rails console on the server
kamal logs     # Tail production logs
```
