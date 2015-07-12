class CreatePosts < ActiveRecord::Migration
  def change
    create_table :posts do |t|
      t.text :body
      t.references :user, index: true, foreign_key: true
      t.boolean :official

      t.timestamps null: false
    end
  end
end