  class InitialMigration < ActiveRecord::Migration[5.2]
  def change
    create_table :state do |t|
      t.integer :latest_block_num
      t.timestamp :latest_payout_at
      t.bigint :latest_avg_rshares
      t.timestamp :latest_avg_rshares_at
    end
    
    create_table :posts do |t|
      t.string :author, null: false
      t.string :permlink, null: false
      t.bigint :upvote_rshares, null: false
      t.bigint :downvote_rshares, null: false
      t.string :top_upvoter, null: false
      t.string :top_downvoter, null: false
      t.timestamp :payout_at, null: false
      t.float :stingy_payout_amount, null: false, default: Stingy::Post::DEFAULT_STINGY_PAYOUT_AMOUNT
      t.boolean :stingy_payout_applied, null: false, default: '0'
      t.timestamps null: false
    end
    
    create_table :users do |t|
      t.string :name, null: false
      t.float :stingy_payout_amount, null: false, default: 0.0
      t.timestamp :opt_in_at
      t.timestamps null: false
    end
  end
end
