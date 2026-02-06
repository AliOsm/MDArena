class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :project, null: false, foreign_key: true
      t.string :path, null: false
      t.string :last_commit_sha
      t.datetime :last_modified_at

      t.timestamps
    end

    add_index :documents, %i[project_id path], unique: true
  end
end
