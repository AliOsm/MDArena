require "active_model/type/boolean"
require "digest"
require "fileutils"

class YdocLock
  # Distributed lock for ydoc read/modify/write across:
  # - web processes/containers (ActionCable updates)
  # - job processes/containers (flush/cleanup jobs)
  #
  # We use Postgres advisory locks so coordination works across containers/hosts.
  def self.with_lock(project_id, file_path)
    with_advisory_lock(lock_key("ydoc:#{project_id}:#{file_path}")) { yield }
  end

  def self.with_registry_lock
    with_advisory_lock(lock_key("ydoc-registry")) { yield }
  end

  def self.with_advisory_lock(key)
    # Fallback to a local lock file if Postgres isn't available (shouldn't happen
    # in production, but keeps development setups flexible).
    return with_file_lock(key) { yield } unless postgres?

    conn = nil
    boolean = ActiveModel::Type::Boolean.new

    ActiveRecord::Base.connection_pool.with_connection do |c|
      conn = c

      # `pg_advisory_lock` returns `void` which triggers noisy "unknown OID" warnings
      # in Ruby PG type mapping. Use `pg_try_advisory_lock` in a loop instead.
      loop do
        locked = conn.select_value("SELECT pg_try_advisory_lock(#{key})")
        break if boolean.cast(locked)
        sleep 0.01
      end

      yield
    ensure
      begin
        conn&.select_value("SELECT pg_advisory_unlock(#{key})")
      rescue ActiveRecord::StatementInvalid
        # If the connection died, Postgres releases advisory locks automatically.
      end
    end
  end

  def self.lock_key(token)
    Digest::SHA256.digest(token).unpack1("q>")
  end

  def self.postgres?
    ActiveRecord::Base.connection.adapter_name.to_s.casecmp("postgresql").zero?
  rescue ActiveRecord::ConnectionNotEstablished
    false
  end

  def self.with_file_lock(key)
    lock_path = Rails.root.join("tmp", "ydoc-locks", "#{key}.lock")
    FileUtils.mkdir_p(lock_path.dirname)
    File.open(lock_path, File::CREAT | File::RDWR) do |f|
      f.flock(File::LOCK_EX)
      yield
    end
  end

  private_class_method :with_advisory_lock, :lock_key, :postgres?, :with_file_lock
end
