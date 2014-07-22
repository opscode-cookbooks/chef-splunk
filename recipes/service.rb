#
# Cookbook Name:: splunk
# Recipe:: service
#
# Author: Joshua Timberman <joshua@getchef.com>
# Copyright (c) 2014, Chef Software, Inc <legal@getchef.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if node['splunk']['accept_license']
  execute "#{splunk_cmd} enable boot-start --accept-license --answer-yes" do
    not_if { ::File.exist?('/etc/init.d/splunk') }
  end
end

# if runasroot is false run the command to modify the splunk init script to
# run as a non-privileged user otherwise we run as root
execute 'update-splunk-init-script-to-run-as-splunk-user' do
  command "#{splunk_cmd} enable boot-start -user #{node['splunk']['user']['username']}"
  only_if node['splunk']['id_server']
  not_if "grep -q /bin/su /etc/init.d/splunk"
  not_if node['splunk']['server']['runasroot']
end

ruby_block "set \'#{node['splunk']['user']['username']}\' ownership for files in #{splunk_dir}" do
  block do
    FileUtils.chown_R(node['splunk']['user']['username'], node['splunk']['user']['username'], "#{splunk_dir}")
  end
  not_if node['splunk']['server']['runasroot']
  only_if { Etc.getpwuid(::File.stat("#{splunk_dir}/etc/licenses/download-trial").uid).name == 'root' }
end

service 'splunk' do
  supports :status => true, :restart => true
  provider Chef::Provider::Service::Init
  action :start
end
