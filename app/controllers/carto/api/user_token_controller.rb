# encoding: UTF-8

require_relative '../../../models/carto/permission'
require_dependency 'carto/uuidhelper'

module Carto
  module Api
    class UserTokenController < ::Api::ApplicationController
      include Carto::UUIDHelper
      ssl_required :show, :create

      before_filter :load_user_table, only: [:show, :create]
      before_filter :read_privileges?, only: [:show]
      before_filter :write_privileges?, only: [:create]


      def create
        token = random_uuid
        @user_table.visualization.permission.set_usertoken_permission(token,permission_param)
        @user_table.visualization.permission.save
        render_jsonp(user_token: token)
      end

      def permission_param
        rx = /r|rw/
        if params[:perm].present? && rx.match(params[:perm])
          params[:perm]
        else
          Permission::ACCESS_READONLY
        end
      end

      def load_user_table
        @user_table = Carto::Helpers::TableLocator.new.get_by_id_or_name(params[:table_id], current_user)
        raise RecordNotFound unless @user_table
      end

      def read_privileges?
        head(401) unless current_user && @user_table.visualization.is_viewable_by_user?(current_user)
      end

      def write_privileges?
        ead(401) unless current_user && @user_table.visualization.writable_by?(current_user)
      end
    end
  end
end

