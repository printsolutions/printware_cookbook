#
# Cookbook:: printware
# Recipe:: admin_setup
#
# Created by Stas Lisetsky
# stas.lisetsky@gmail.com
#
# Teamcity code: butchered version of chef-teamcity
# https://supermarket.chef.io/cookbooks/teamcity

#
# Cookbook:: printware
# Recipe:: default

# apt_update 'daily' do
#   frequency 86_400
#   action :periodic
# end

TEAMCITY_USERNAME = node['teamcity']['username'].freeze
TEAMCITY_PASSWORD = node['teamcity']['password'].freeze
TEAMCITY_GROUP = node['teamcity']['group'].freeze
TEAMCITY_HOME_PATH = "/home/#{TEAMCITY_USERNAME}".freeze

TEAMCITY_VERSION = node['teamcity']['version'].freeze
TEAMCITY_SERVICE_NAME = node['teamcity']['service_name'].freeze
TEAMCITY_PATH = "/opt/TeamCity-#{TEAMCITY_VERSION}".freeze
TEAMCITY_INIT_LOCATION = "/etc/init.d/#{TEAMCITY_SERVICE_NAME}".freeze
TEAMCITY_EXECUTABLE_MODE = 0755
TEAMCITY_READ_MODE = 0644

TEAMCITY_SRC_PATH = "#{TEAMCITY_PATH}.tar.gz"
TEAMCITY_PID_FILE = "#{TEAMCITY_PATH}/logs/#{TEAMCITY_SERVICE_NAME}.pid"
TEAMCITY_DB_USERNAME = node.default['teamcity']['database']['username']
TEAMCITY_DB_PASSWORD = node.default['teamcity']['database']['password']

TEAMCITY_DB_CONNECTION_URL = node['teamcity']['database']['connection_url']
TEAMCITY_SERVER_EXECUTABLE = "#{TEAMCITY_PATH}/bin/teamcity-server.sh"
TEAMCITY_BIN_PATH = "#{TEAMCITY_PATH}/bin"
TEAMCITY_DATA_PATH = "#{TEAMCITY_PATH}/.BuildServer"
TEAMCITY_LIB_PATH = "#{TEAMCITY_DATA_PATH}/lib"
TEAMCITY_JDBC_PATH = "#{TEAMCITY_LIB_PATH}/jdbc"
TEAMCITY_CONFIG_PATH = "#{TEAMCITY_DATA_PATH}/config"
TEAMCITY_BACKUP_PATH = "#{TEAMCITY_DATA_PATH}/backup"
TEAMCITY_DATABASE_PROPS_NAME = 'database.properties'
TEAMCITY_DATABASE_PROPS_PATH = "#{TEAMCITY_CONFIG_PATH}/#{TEAMCITY_DATABASE_PROPS_NAME}"
TEAMCITY_JAR_URI = node['teamcity']['database']['jar']
TEAMCITY_JAR_NAME = ::File.basename(URI.parse(TEAMCITY_JAR_URI).path)

include_recipe 'java'

git_client 'default' do
	action :install
end

group TEAMCITY_GROUP

user TEAMCITY_USERNAME do
	manage_home true
	home TEAMCITY_HOME_PATH
	gid TEAMCITY_GROUP
	shell '/bin/bash'
	password TEAMCITY_PASSWORD
end

remote_file TEAMCITY_SRC_PATH do
  source "http://download.jetbrains.com/teamcity/TeamCity-#{TEAMCITY_VERSION}.tar.gz"
  owner TEAMCITY_USERNAME
  group TEAMCITY_GROUP
  mode TEAMCITY_READ_MODE
end

bash 'extract_teamcity' do
  cwd '/opt'
  code <<-EOH
    mkdir -p #{TEAMCITY_PATH}
    tar xzf #{TEAMCITY_SRC_PATH} -C #{TEAMCITY_PATH}
    mv #{TEAMCITY_PATH}/*/* #{TEAMCITY_PATH}/
    chown -R #{TEAMCITY_USERNAME}.#{TEAMCITY_GROUP} #{TEAMCITY_PATH}
  EOH
  not_if { ::File.exist?(TEAMCITY_PATH) }
end

paths = [
  TEAMCITY_DATA_PATH,
  TEAMCITY_LIB_PATH,
  TEAMCITY_JDBC_PATH,
  TEAMCITY_CONFIG_PATH,
  TEAMCITY_BACKUP_PATH
]

paths.each do |p|
  directory p do
    owner TEAMCITY_USERNAME
    group TEAMCITY_GROUP
    recursive true
    mode TEAMCITY_EXECUTABLE_MODE
  end
end

remote_file "#{TEAMCITY_JDBC_PATH}/#{TEAMCITY_JAR_NAME}" do
  source TEAMCITY_JAR_URI
  owner TEAMCITY_USERNAME
  group TEAMCITY_GROUP
  mode TEAMCITY_READ_MODE
end

template TEAMCITY_DATABASE_PROPS_PATH do
  source 'database.properties.erb'
  mode TEAMCITY_READ_MODE
  owner TEAMCITY_USERNAME
  group TEAMCITY_GROUP
  variables(
              url: TEAMCITY_DB_CONNECTION_URL,
              username: TEAMCITY_DB_USERNAME,
              password: TEAMCITY_DB_PASSWORD
            )
  notifies :restart, "service[#{TEAMCITY_SERVICE_NAME}]", :delayed
end

template TEAMCITY_INIT_LOCATION do
  source 'teamcity_server_init.erb'
  mode TEAMCITY_EXECUTABLE_MODE
  owner 'root'
  group 'root'
  variables(
              teamcity_user_name: TEAMCITY_USERNAME,
              teamcity_server_executable: TEAMCITY_SERVER_EXECUTABLE,
              teamcity_data_path: TEAMCITY_DATA_PATH,
              teamcity_pidfile: TEAMCITY_PID_FILE,
              teamcity_service_name: TEAMCITY_SERVICE_NAME
            )
  notifies :restart, "service[#{TEAMCITY_SERVICE_NAME}]", :delayed
end

service TEAMCITY_SERVICE_NAME do
  supports start: true, stop: true, restart: true, status: true
  action [:enable, :start]
end
