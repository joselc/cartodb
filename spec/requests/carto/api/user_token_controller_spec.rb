# encoding: utf-8

require_relative '../../../spec_helper'

describe Carto::Api::UserTokenController do

  before(:all) do
    @user = FactoryGirl.create(:valid_user)
    @user2 = FactoryGirl.create(:valid_user)
    @table = create_table(user_id: @user.id)
    @table2 = create_table(user_id: @user2.id)
    @user_token_rx = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
  end

  after(:all) do
    @user.destroy
    @user2.destroy
  end

  let(:params) {{api_key: @user.api_key, table_id: @table.name, user_domain: @user.username}}

  it "Should create a user token for user table" do
    post_json api_v1_tables_usertokens_create_url(params) do |response|
      response.status.should be_success
      response.body[:user_token].should match(@user_token_rx)
      response.body[:perm].should match(Permission::ACCESS_READONLY)
    end
  end

  it "Shouldn't create s user token for other user table" do
    post_json api_v1_tables_usertokens_create_url(params.merge(table_id: @user2.username + "." + @table2.name)) do |response|
      response.status.should_not be_success
    end
  end

  it "Should create a readonly user token for user table" do
    post_json api_v1_tables_usertokens_create_url(params.merge(perm: Permission::ACCESS_READONLY)) do |response|
      response.status.should be_success
      response.body[:user_token].should match(@user_token_rx)
      response.body[:perm].should match(Permission::ACCESS_READONLY)
    end
  end

  it "Should create a readwrite user token for user table" do
    post_json api_v1_tables_usertokens_create_url(params.merge(perm: Permission::ACCESS_READWRITE)) do |response|
      response.status.should be_success
      response.body[:user_token].should match(@user_token_rx)
      response.body[:perm].should match(Permission::ACCESS_READWRITE)
    end
  end
end
