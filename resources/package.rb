provides :python_package

property :package_name, [String, Array], name_property: true
property :version, [String, Array], desired_state: true
property :python, String
property :virtualenv, String, desired_state: true, identity: true
property :group, [String, Integer, NilClass]
property :user, [String, Integer, NilClass]

property :python_version, [String, FalseClass], default: lazy { node['python3']['version'] }
property :python_provider, [String, nil], default: lazy { node['python3']['source'] }

load_current_value do |new_resource|
  packages = ::Kernel.Array(new_resource.package_name)
  current_versions = []
  packages.each do |pkg|
    v = ::Python3::Pip.check_package_version(pkg.downcase, ::Python3::Path.virtualenv(new_resource))
    current_value_does_not_exist! if v.nil?
    current_versions << v
  end

  if packages.size == 1
    package_name packages.first
    version current_versions.first
  else
    package_name packages
    version current_versions
  end
end

action :install do
  converge_if_changed :version do
    converge_by("Install #{new_resource.package_name}") do
      venv_path = ::Python3::Path.virtualenv(new_resource)
      if new_resource.package_name.is_a?(String)
        install_package(venv_path, new_resource.package_name, new_resource.version)
      else
        new_resource.package_name.each_with_index do |pkg, i|
          version = new_resource.version.to_a.at(i)
          install_package(venv_path, pkg, version)
        end
      end
    end
  end
end

def install_package(virtualenv, pkg, version)
  pkg += "==#{version}" if version

  Mixlib::ShellOut.new("#{::Python3::Pip.path(virtualenv)} install #{pkg}").run_command
end
