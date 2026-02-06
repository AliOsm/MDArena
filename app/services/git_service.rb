class GitService
  REPOS_ROOT = Rails.configuration.repos_root

  class StaleCommitError < StandardError; end
  class FileNotFoundError < StandardError; end

  def self.repo_path(project)
    File.join(REPOS_ROOT, "#{project.uuid}.git")
  end

  def self.init_repo(project)
    Rugged::Repository.init_at(repo_path(project), :bare)
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
  end

  def self.list_files(project, ref: "HEAD")
    repo = Rugged::Repository.new(repo_path(project))
    commit = resolve_commit(repo, ref)
    files = []
    commit.tree.walk_blobs { |root, entry| files << "#{root}#{entry[:name]}" }
    files
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
  end

  def self.file_content_at(project, path, sha)
    repo = Rugged::Repository.new(repo_path(project))
    commit = repo.lookup(sha)
    entry = commit.tree.path(path)
    repo.lookup(entry[:oid]).content
  rescue Rugged::TreeError
    raise FileNotFoundError, "File not found: #{path} at #{sha}"
  rescue Rugged::OdbError, Rugged::InvalidError
    raise FileNotFoundError, "Commit not found: #{sha}"
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
