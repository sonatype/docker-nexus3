# Copyright (c) 2016-present Sonatype, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "serverspec"
require "docker"

describe 'Dockerfile' do
  before(:all) do
    Docker.options[:read_timeout] = 900
    @image = Docker::Image.get(ENV['IMAGE_ID'])

    set :os, family: :redhat
    set :backend, :docker
    set :docker_image, @image.id
  end

  it 'should remove solo.json during cleanup' do
    expect(File).not_to exist('/var/chef/solo.json')
  end

  it 'should not have a chef package installed' do
    expect(package('chef')).not_to be_installed
  end

  it 'should have a user named nexus' do
    expect(user('nexus')).to exist
  end

  it 'should have a nexus process running' do
    expect(process('java')).to be_running
    expect(process('java')).to have_attributes(:user => 'nexus')
  end
end
