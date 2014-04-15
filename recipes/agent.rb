# encoding: UTF-8
#
# Cookbook Name:: rackspace_cloudmonitoring
# Recipe:: agent
#
# Install and configure the cloud monitoring agent on a server
#
# Copyright 2014, Rackspace, US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Include dependency recipes
include_recipe 'rackspace_cloudmonitoring::default'

if platform_family?('debian')
  rackspace_apt_repository 'cloud-monitoring' do

    if node['platform'] == 'ubuntu'
      uri "http://stable.packages.cloudmonitoring.rackspace.com/ubuntu-#{node['platform_version']}-#{node['kernel']['machine']}"
    elsif node['platform'] == 'debian'
      uri "http://stable.packages.cloudmonitoring.rackspace.com/debian-#{node['lsb']['codename']}-#{node['kernel']['machine']}"
    end

    distribution 'cloudmonitoring'
    components ['main']
    key 'https://monitoring.api.rackspacecloud.com/pki/agent/linux.asc'
    action :add
  end

elsif platform_family?('rhel')
  # do RHEL things

  # Grab the major release for cent and rhel servers as this is what the repos use.
  release_version = node['platform_version'].split('.').first

  # We need to figure out which signing key to use, cent5 and rhel5 have their own.
  if (node['platform'] == 'centos') && (release_version == '5')
    signing_key = 'https://monitoring.api.rackspacecloud.com/pki/agent/centos-5.asc'
  elsif (node['platform'] == 'redhat') && (release_version == '5')
    signing_key = 'https://monitoring.api.rackspacecloud.com/pki/agent/redhat-5.asc'
  else
    signing_key = 'https://monitoring.api.rackspacecloud.com/pki/agent/linux.asc'
  end

  rackspace_yum_key 'Rackspace-Monitoring' do
    url signing_key
    action :add
  end

  rackspace_yum_repository 'cloud-monitoring' do
    description 'Rackspace Monitoring'
    url "http://stable.packages.cloudmonitoring.rackspace.com/#{node['platform']}-#{release_version}-#{node['kernel']['machine']}"
    action :add
  end
end

# Hook into the cloud_monitoring module to get access to the CMAgentToken and CMCredentials classes
# This is the easiest way to pull out the token and id generated by the LWRP
class Chef::Recipe
  include Opscode::Rackspace::Monitoring
end

# Pull the token using the CMCredentials class, which handles node and databag variables
credentials = CMCredentials.new(node, nil)
node.set['rackspace_cloudmonitoring']['config']['agent']['token'] = credentials.get_attribute(:token)

# If the token or id was not specified, call the API to generate/locate it.
if node['rackspace_cloudmonitoring']['config']['agent']['token'].nil? || node['rackspace_cloudmonitoring']['config']['agent']['id'].nil?
  e = rackspace_cloudmonitoring_agent_token node['hostname'] do
    token               node['rackspace_cloudmonitoring']['config']['agent']['token']
    action :nothing
  end

  e.run_action(:create)

  my_token_obj = CMAgentToken.new(credentials, node['rackspace_cloudmonitoring']['config']['agent']['token'], node['hostname'])
  my_token = my_token_obj.obj

  unless my_token.nil?
    node.set['rackspace_cloudmonitoring']['config']['agent']['token'] = my_token.token
    # So the API calls it label, and the config calls it ID
    # Clear as mud.
    node.set['rackspace_cloudmonitoring']['config']['agent']['id'] = my_token.label
  end
end

if node['rackspace_cloudmonitoring']['config']['agent']['token'].nil? || node['rackspace_cloudmonitoring']['config']['agent']['id'].nil?
  Chef::Log.warn('Unable to determine agent token and id: Not configuring agent')
else
  # Generate the config template
  template '/etc/rackspace-monitoring-agent.cfg' do
    source 'rackspace-monitoring-agent.erb'
    cookbook node['rackspace_cloudmonitoring']['templates_cookbook']['rackspace-monitoring-agent']
    owner 'root'
    group 'root'
    mode 0600
    variables(
              monitoring_id:    node['rackspace_cloudmonitoring']['config']['agent']['id'],
              monitoring_token: node['rackspace_cloudmonitoring']['config']['agent']['token']
              )
    action :create
  end

  package 'rackspace-monitoring-agent' do
    if node['rackspace_cloudmonitoring']['agent']['version'] == 'latest'
      Chef::Log.info('Installing latest agent')
      action :upgrade
    else
      Chef::Log.info("Installing agent version #{node['rackspace_cloudmonitoring']['agent']['version']}")
      version node['rackspace_cloudmonitoring']['agent']['version']
      action :install
    end

    notifies :restart, 'service[rackspace-monitoring-agent]'
  end

  service 'rackspace-monitoring-agent' do
    supports value_for_platform(
                                ubuntu:  { default: [:start, :stop, :restart, :status] },
                                default: { default: [:start, :stop] }
                                )

    case node['platform']
    when 'ubuntu'
      if node['platform_version'].to_f >= 9.10
        provider Chef::Provider::Service::Upstart
      end
  end

    action [:enable, :start]
    subscribes :restart, "template['/etc/rackspace-monitoring-agent.cfg']", :delayed
  end
end

# Handle plugins directory and plugins
# Explicitly create the directory to avoid convergence failures, don't rely on the agent
# (Note agent install is inside a conditional.)
directory node['rackspace_cloudmonitoring']['agent']['plugin_path'] do
  owner 'root'
  group 'root'
  mode 00755
  action :create
end

node['rackspace_cloudmonitoring']['agent']['plugins'].each_pair do |source_cookbook, path|
  remote_directory "rackspace_cloudmonitoring_plugins_#{source_cookbook}" do
    path node['rackspace_cloudmonitoring']['agent']['plugin_path']
    cookbook source_cookbook
    source path
    files_mode 0755
    owner 'root'
    group 'root'
    mode 0755
    recursive true
    purge false
  end
end
