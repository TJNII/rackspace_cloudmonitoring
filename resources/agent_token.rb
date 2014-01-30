# encoding: UTF-8
actions :create, :create_if_missing, :delete
default_action :create

attribute :label, kind_of:  String, name_attribute:  true
attribute :token, kind_of:  String

attribute :rackspace_api_key, kind_of:  String
attribute :rackspace_username, kind_of:  String
attribute :rackspace_auth_url, kind_of:  String
