require 'spec_helper'

describe 'chef-splunk::server' do
  let(:chef_run_init) do
    ChefSpec::ServerRunner.new do |node, server|
      node.force_default['dev_mode'] = true
      node.force_default['splunk']['is_server'] = true
      node.force_default['splunk']['accept_license'] = true
      # Populate mock vault data bag to the server
      create_data_bag_item(server, 'vault', 'splunk__default')
    end
  end

  let(:chef_run) do
    chef_run_init.converge(described_recipe)
  end

  before(:each) do
    allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).and_return(true)
    stub_command("/opt/splunk/bin/splunk enable listen 9997 -auth 'admin:notarealpassword'").and_return(true)
    # Stub TCP Socket to immediately fail connection to 9997 and raise error without waiting for entire default timeout
    allow(TCPSocket).to receive(:new).with(anything, '9997') { raise Errno::ETIMEDOUT }
  end

  context 'default settings' do
    before(:each) do
      stub_command("/opt/splunk/bin/splunk show splunkd-port -auth 'admin:notarealpassword' | grep ': 8089'").and_return('Splunkd port: 8089')
    end

    it 'does not update splunkd management port' do
      expect(chef_run).to_not run_execute('update-splunk-mgmt-port')
    end

    it 'enables receiver port' do
      expect(chef_run).to run_execute('enable-splunk-receiver-port').with(
        'command' => "/opt/splunk/bin/splunk enable listen 9997 -auth 'admin:notarealpassword'"
      )
    end
  end

  context 'custom management port' do
    before(:each) do
      stub_command("/opt/splunk/bin/splunk show splunkd-port -auth 'admin:notarealpassword' | grep ': 9089'").and_return(false)
      chef_run_init.node.force_default['splunk']['mgmt_port'] = '9089'
    end

    it 'updates splunkd management port' do
      expect(chef_run).to run_execute('update-splunk-mgmt-port').with(
        'command' => "/opt/splunk/bin/splunk set splunkd-port 9089 -auth 'admin:notarealpassword'"
      )
    end

    it 'notifies the splunk service to restart when changing management port' do
      execution = chef_run.execute('update-splunk-mgmt-port')
      expect(execution).to notify('service[splunk]').to(:restart)
    end

    it 'enables receiver port' do
      expect(chef_run).to run_execute('enable-splunk-receiver-port').with(
        'command' => "/opt/splunk/bin/splunk enable listen 9997 -auth 'admin:notarealpassword'"
      )
    end
  end
end
