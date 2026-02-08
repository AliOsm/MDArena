class GitService
  class StaleCommitError < StandardError; end
  class FileNotFoundError < StandardError; end

  def self.repos_root
    Rails.configuration.repos_root
  end

  def self.repo_path_for_uuid(uuid)
    File.join(repos_root, "#{uuid}.git")
  end

  def self.repo_path(project)
    repo_path_for_uuid(project.uuid)
  end

  def self.init_repo(project)
    path = repo_path(project)
    FileUtils.mkdir_p(File.dirname(path))

    repo = Rugged::Repository.init_at(path, :bare)
    repo.head = "refs/heads/main"
    repo.config["http.receivepack"] = "true"
    repo
  end

  def self.delete_repo(project)
    return unless project&.uuid.present?

    root = File.expand_path(repos_root)
    path = File.expand_path(repo_path(project))

    # Defense in depth: avoid deleting anything outside the configured repo root.
    return unless path.start_with?(root.end_with?(File::SEPARATOR) ? root : (root + File::SEPARATOR))

    FileUtils.rm_rf(path)
  end

  def self.with_repo_lock(project)
    lock_path = "#{repo_path(project)}.lock"
    FileUtils.mkdir_p(File.dirname(lock_path))
    File.open(lock_path, File::CREAT | File::RDWR) do |f|
      f.flock(File::LOCK_EX)
      yield
    end
  end

  def self.read_file(project, path, ref: "HEAD")
    repo = Rugged::Repository.new(repo_path(project))
    commit = repo.references["refs/heads/main"]&.target || repo.head.target
    commit = resolve_commit(repo, ref) if ref != "HEAD"
    tree = commit.tree
    entry = tree.path(path)
    repo.lookup(entry[:oid]).content
  rescue Rugged::RepositoryError
    raise FileNotFoundError, "Repository not found"
  rescue Rugged::TreeError
    raise FileNotFoundError, "File not found: #{path}"
  rescue Rugged::ReferenceError
    raise FileNotFoundError, "Repository has no commits"
  end

  def self.commit_file(project:, path:, content:, user:, message:, base_sha: nil)
    with_repo_lock(project) do
      repo = Rugged::Repository.new(repo_path(project))

      if base_sha && repo.references["refs/heads/main"]
        head_sha = repo.references["refs/heads/main"].target.oid
        raise StaleCommitError, "Expected #{base_sha} but HEAD is #{head_sha}" if base_sha != head_sha
      end

      oid = repo.write(content, :blob)
      index = Rugged::Index.new
      if repo.references["refs/heads/main"]
        current_tree = repo.references["refs/heads/main"].target.tree
        index.read_tree(current_tree)
      end
      index.add(path: path, oid: oid, mode: 0100644)
      tree_oid = index.write_tree(repo)

      author = { name: user.name, email: user.email, time: Time.now }
      parents = repo.references["refs/heads/main"] ? [ repo.references["refs/heads/main"].target ] : []

      commit_oid = Rugged::Commit.create(repo,
        tree: tree_oid,
        author: author,
        committer: author,
        message: message,
        parents: parents,
        update_ref: "refs/heads/main")

      commit_oid
    end
  rescue Rugged::RepositoryError
    raise FileNotFoundError, "Repository not found"
  end

  def self.list_files(project, ref: "HEAD")
    repo = Rugged::Repository.new(repo_path(project))
    commit = resolve_commit(repo, ref)
    files = []
    commit.tree.walk_blobs { |root, entry| files << "#{root}#{entry[:name]}" }
    files
  rescue Rugged::RepositoryError
    []
  rescue Rugged::ReferenceError
    []
  end

  def self.file_history(project, path)
    repo = Rugged::Repository.new(repo_path(project))
    ref = repo.references["refs/heads/main"]
    return [] unless ref

    commits = []
    walker = Rugged::Walker.new(repo)
    walker.sorting(Rugged::SORT_TOPO | Rugged::SORT_DATE)
    walker.push(ref.target.oid)

    walker.each do |commit|
      parent = commit.parents.first
      current_oid = blob_oid_at(commit.tree, path)
      parent_oid = parent ? blob_oid_at(parent.tree, path) : nil

      next if current_oid.nil?
      next if current_oid == parent_oid

      commits << {
        sha: commit.oid,
        message: commit.message,
        author: { name: commit.author[:name], email: commit.author[:email] },
        time: commit.author[:time]
      }
    end

    commits
  rescue Rugged::RepositoryError
    []
  end

  def self.delete_file(project:, path:, user:, message:)
    with_repo_lock(project) do
      repo = Rugged::Repository.new(repo_path(project))
      ref = repo.references["refs/heads/main"]
      raise FileNotFoundError, "Repository has no commits" unless ref

      current_tree = ref.target.tree
      begin
        current_tree.path(path)
      rescue Rugged::TreeError
        raise FileNotFoundError, "File not found: #{path}"
      end

      index = Rugged::Index.new
      index.read_tree(current_tree)
      index.remove(path)
      tree_oid = index.write_tree(repo)

      author = { name: user.name, email: user.email, time: Time.now }

      Rugged::Commit.create(repo,
        tree: tree_oid,
        author: author,
        committer: author,
        message: message,
        parents: [ ref.target ],
        update_ref: "refs/heads/main")
    end
  rescue Rugged::RepositoryError
    raise FileNotFoundError, "Repository not found"
  end

  def self.file_content_at(project, path, sha)
    repo = Rugged::Repository.new(repo_path(project))
    commit = repo.lookup(sha)
    entry = commit.tree.path(path)
    repo.lookup(entry[:oid]).content
  rescue Rugged::RepositoryError
    raise FileNotFoundError, "Repository not found"
  rescue Rugged::TreeError
    raise FileNotFoundError, "File not found: #{path} at #{sha}"
  rescue Rugged::OdbError, Rugged::InvalidError
    raise FileNotFoundError, "Commit not found: #{sha}"
  end

  def self.head_sha(project)
    repo = Rugged::Repository.new(repo_path(project))
    repo.references["refs/heads/main"]&.target&.oid
  rescue Rugged::RepositoryError
    nil
  end

  def self.resolve_commit(repo, ref)
    if ref == "HEAD"
      repo.references["refs/heads/main"]&.target || repo.head.target
    else
      repo.lookup(ref)
    end
  end

  def self.blob_oid_at(tree, path)
    tree.path(path)[:oid]
  rescue Rugged::TreeError
    nil
  end

  private_class_method :resolve_commit, :blob_oid_at
end
