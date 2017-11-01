require 'carto/db/migration_helper'

include Carto::Db::MigrationHelper

migration(
    Proc.new do
      create_table :user_tokens do
        Uuid :id, primary_key: true, default: 'uuid_generate_v4()'.lit
        foreign_key :user_table_id, :user_tables, null: false, type: :uuid, on_delete: :cascade
        foreign_key :user_id, :users, null: false, type: :uuid, on_delete: :cascade
        String :permissions, null: false, default: Carto::UserToken::ACCESS_READONLY
        DateTime    :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      end
    end,
    Proc.new do
      drop_table :user_tokens
    end

)
