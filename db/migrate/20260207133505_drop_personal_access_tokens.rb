class DropPersonalAccessTokens < ActiveRecord::Migration[8.1]
  def change
    drop_table :personal_access_tokens
  end
end
