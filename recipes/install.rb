# http://solutions.treypiepmeier.com/2010/02/28/installing-mysql-on-snow-leopard-using-homebrew/
require 'pathname'

PASSWORD = node['sprout']['mysql']['root_password']
# The next two directories will be owned by node['sprout']['user']
DATA_DIR = '/usr/local/var/mysql'
PARENT_DATA_DIR = '/usr/local/var'

include_recipe 'sprout-base::homebrew'

["/Users/#{node['sprout']['user']}/Library/LaunchAgents",
 PARENT_DATA_DIR,
 DATA_DIR].each do |dir|
  directory dir do
    owner node['sprout']['user']
    action :create
  end
end

package 'mysql'

ruby_block 'copy mysql plist to ~/Library/LaunchAgents' do
  block do
    active_mysql = Pathname.new('/usr/local/bin/mysql').realpath
    plist_location = (active_mysql + '../../' + 'homebrew.mxcl.mysql.plist').to_s
    destination = "#{node['sprout']['home']}/Library/LaunchAgents/homebrew.mxcl.mysql.plist"
    system("cp #{plist_location} #{destination} && chown #{node['sprout']['user']} #{destination}") || fail("Couldn't find the plist")
  end
end

ruby_block 'mysql_install_db' do
  block do
    active_mysql = Pathname.new('/usr/local/bin/mysql').realpath
    basedir = (active_mysql + '../../').to_s
    data_dir = '/usr/local/var/mysql'
    system("mysql_install_db --verbose --user=#{node['sprout']['user']} --basedir=#{basedir} --datadir=#{DATA_DIR} --tmpdir=/tmp && chown #{node['sprout']['user']} #{data_dir}") || fail('Failed initializing mysqldb')
  end
  not_if { File.exist?('/usr/local/var/mysql/mysql/user.MYD') }
end

execute 'load the mysql plist into the mac daemon startup thing' do
  command "launchctl load -w #{node['sprout']['home']}/Library/LaunchAgents/homebrew.mxcl.mysql.plist"
  user node['sprout']['user']
  not_if { system('launchctl list com.mysql.mysqld') }
end

ruby_block 'Checking that mysql is running' do
  block do
    Timeout.timeout(60) do
      until system('ls /tmp/mysql.sock')
        sleep 1
      end
    end
  end
end

execute 'set the root password to the default' do
  command "mysqladmin -uroot password #{PASSWORD}"
  not_if "mysql -uroot -p#{PASSWORD} -e 'show databases'"
end

execute 'insert time zone info' do
  command "mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/XXT/' | mysql -uroot -p#{PASSWORD} mysql"
  not_if "mysql -uroot -p#{PASSWORD} mysql -e 'select * from time_zone_name' | grep -q UTC"
end
