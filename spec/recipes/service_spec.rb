require 'spec_helper'

describe 'chef-splunk::service' do
  context 'splunkd as a server' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new do |node, server|
        create_data_bag_item(server, 'vault', 'splunk__default')
        node.force_default['splunk']['accept_license'] = true
        node.force_default['splunk']['is_server'] = true
        node.force_default['splunk']['startup_script'] = '/etc/systemd/system/Splunkd.service'
        node.automatic['init_package'] = 'systemd'
      end.converge(described_recipe)
    end

    before do
      allow(::File).to receive(:exist?).and_call_original
      allow(::File).to receive(:exist?).with('/etc/systemd/system/Splunkd.service').and_return(true)
    end

    %w(chef-splunk::setup_auth chef-splunk).each do |recipe|
      it "included #{recipe} recipe" do
        expect(chef_run).to include_recipe(recipe)
      end
    end

    it 'creates directory /opt/splunk' do
      expect(chef_run).to create_directory('/opt/splunk').with(mode: '755')
    end

    %w(/opt/splunk/var /opt/splunk/var/log).each do |d|
      it "creates directory #{d}" do
        expect(chef_run).to create_directory(d).with(mode: '711')
      end
    end

    it 'creates directory /opt/splunk/var/log/splunk' do
      expect(chef_run).to create_directory('/opt/splunk/var/log/splunk').with(mode: '700')
    end

    it 'fixes splunk file permissions' do
      expect(chef_run).to run_ruby_block('splunk_fix_file_ownership')
      expect(chef_run.ruby_block('splunk_fix_file_ownership')).to subscribe_to('service[splunk]').on(:run).before
    end

    it 'enables boot-start' do
      expect(chef_run).to run_execute('splunk enable boot-start')
        .with(sensitive: false, retries: 3, creates: '/etc/systemd/system/Splunkd.service')
    end

    it 'links the startup script' do
      expect(chef_run).to create_link('/etc/systemd/system/splunk.service')
    end

    it 'started splunk service' do
      expect(chef_run).to start_service('splunk')
    end
  end

  context 'Splunk is setup as a client' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new do |node, server|
        create_data_bag_item(server, 'vault', 'splunk__default')
        node.force_default['splunk']['accept_license'] = true
        node.force_default['splunk']['is_server'] = false
        node.force_default['splunk']['startup_script'] = '/etc/systemd/system/SplunkForwarder.service'
        node.automatic['init_package'] = 'systemd'
      end.converge(described_recipe)
    end

    before do
      allow(::File).to receive(:exist?).and_call_original
      allow(::File).to receive(:exist?).with('/etc/systemd/system/SplunkForwarder.service').and_return(true)
    end

    %w(chef-splunk::setup_auth chef-splunk).each do |recipe|
      it "included #{recipe} recipe" do
        expect(chef_run).to include_recipe(recipe)
      end
    end

    it 'creates directory /opt/splunk' do
      expect(chef_run).to_not create_directory('/opt/splunk').with(mode: '755')
    end

    %w(/opt/splunk/var /opt/splunk/var/log).each do |d|
      it "creates directory #{d}" do
        expect(chef_run).to_not create_directory(d).with(mode: '711')
      end
    end

    it 'creates directory /opt/splunk/var/log/splunk' do
      expect(chef_run).to_not create_directory('/opt/splunk/var/log/splunk').with(mode: '700')
    end

    it 'fixes splunk file permissions' do
      expect(chef_run).to run_ruby_block('splunk_fix_file_ownership')
      expect(chef_run.ruby_block('splunk_fix_file_ownership')).to subscribe_to('service[splunk]').on(:run).before
    end

    it 'enables boot-start' do
      expect(chef_run).to run_execute('splunk enable boot-start')
        .with(sensitive: false, retries: 3, creates: '/etc/systemd/system/SplunkForwarder.service')
    end

    it 'started splunk service' do
      expect(chef_run).to start_service('splunk')
    end
  end
end
