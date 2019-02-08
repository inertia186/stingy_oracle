# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_01_02_221011) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "posts", force: :cascade do |t|
    t.string "author", null: false
    t.string "permlink", null: false
    t.bigint "upvote_rshares", null: false
    t.bigint "downvote_rshares", null: false
    t.string "top_upvoter", null: false
    t.string "top_downvoter", null: false
    t.datetime "payout_at", null: false
    t.float "stingy_payout_amount", default: 1.0, null: false
    t.boolean "stingy_payout_applied", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "state", force: :cascade do |t|
    t.integer "latest_block_num"
    t.datetime "latest_payout_at"
    t.bigint "latest_avg_rshares"
    t.datetime "latest_avg_rshares_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.float "stingy_payout_amount", default: 0.0, null: false
    t.datetime "opt_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
