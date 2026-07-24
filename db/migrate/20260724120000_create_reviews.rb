class CreateReviews < ActiveRecord::Migration[7.2]
  def change
    create_table :reviews do |t|
      t.references :book, null: false, foreign_key: true
      t.string :reviewer, null: false
      t.integer :rating, null: false
      t.text :body

      t.timestamps
    end
  end
end
