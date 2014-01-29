#
# Cookbook Name:: rackspace_cloudmonitoring
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

require_relative '../../../libraries/CMApi.rb'
require_relative '../../../libraries/CMCredentials.rb'
require_relative '../../../libraries/CMEntity.rb'
include Opscode::Rackspace::Monitoring

def test_credentials
  return CMCredentials.new({
                             'rackspace_cloudmonitoring' => { 'mock' => true },
                             'rackspace' => { 'cloud_credentials' => {
                                 'username' => 'Mr. Mockson',
                                 'api_key'  => 'Woodruff'
                               } }
                           }, nil)
end

def generate_token(credentials, label)
  fail 'ERROR: nil credentials' if credentials.nil?
  cm = CMApi.new(credentials).cm
  token = cm.agent_tokens.find { |t| t.label == label }
  if token.nil?
    token = cm.agent_tokens.new
    token.label = label
    token.save
  end
  return token
end

def generate_entity(credentials = test_credentials, label = "Testing Entity")
  fail 'ERROR: nil credentials' if credentials.nil?
  cm = CMApi.new(credentials).cm
  entity = cm.entities.find { |e| e.label == label }
  if entity.nil?
    entity = cm.entities.new
    entity.label = label
    entity.save
  end
  return entity
end

def generate_alarm(entity, label = "Testing Alarm", check_id = "Test Check", notification_plan_id = "Test Notification Plan")
  fail 'ERROR: nil entity' if entity.nil?
  alarm = entity.alarms.find { |x| x.label == label }
  if alarm.nil?
    alarm = entity.alarms.new(
                              "label" => label,
                              "check" => check_id,
                              "notification_plan_id" => notification_plan_id,
                              )
    alarm.save
  end
  return alarm
end
