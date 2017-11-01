require 'active_record'

module Carto
  class UserToken < ActiveRecord::Base
    ACCESS_READONLY   = 'r'.freeze
    ACCESS_READWRITE  = 'rw'.freeze

    belongs_to :user, class_name: Carto::User, select: Carto::User::DEFAULT_SELECT
    belongs_to :user_table, class_name: Carto::UserTable

    def read_access?
      readwrite_access? || permissions == ACCESS_READONLY
    end

    def readwrite_access?
      permissions == ACCESS_READWRITE
    end
  end
end