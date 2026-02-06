class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.uuid :uuid, null: false, default: "gen_random_uuid()"
      t.references :owner, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :projects, :slug, unique: true
    add_index :projects, :uuid, unique: true
  end
end
