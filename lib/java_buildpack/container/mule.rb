# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/container'
require 'java_buildpack/util/tokenized_version'


module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for applications running a simple Java +main()+
    # method. This isn't a _container_ in the traditional sense, but contains the functionality to manage the lifecycle
    # of Java +main()+ applications.
    class Mule < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Container

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        puts "Initialising mule container, component name is: #{@component_name}"
        super(context) { |candidate_version| candidate_version.check_size(3) }
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        puts "***** AT COMPILE: before downloading #{@version} from #{@uri}"
        download(@version, @uri) { |file| expand file }
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        (@application.root + 'mule-deploy.properties').exist?
      end
      
      
      def expand(file)
        with_timing "Expanding Runtime to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
          FileUtils.mkdir_p @droplet.sandbox
          shell "tar xzf #{file.path} -C #{@droplet.sandbox} --strip 1 2>&1"
          
          install_license
          
          deploy_app
          
        end
      end
      
      def install_license
        puts "Installing license -- XXXX TO DO XXXX"
        
      end
      
      def deploy_app
        target = "#{@droplet.sandbox}/apps/app"
        source = "#{@droplet.root}"
        with_timing "Deploying app from #{source} to #{target}" do 
          FileUtils.mkdir_p(target) unless File.exists? target
          Dir.glob("#{source}/**/*").reject{|f| f['.java-buildpack']}.each do |oldfile|
            newfile = target + oldfile.sub(source, '')
            File.file?(oldfile) ? FileUtils.copy(oldfile, newfile) : FileUtils.mkdir(newfile)
          end
        end
      end
      
      # (see JavaBuildpack::Component::BaseComponent#release)
#      def release
##        @droplet.additional_libraries.insert 0, @application.root
##        manifest_class_path.each { |path| @droplet.additional_libraries << path }
##        @droplet.environment_variables.add_environment_variable 'SERVER_PORT', '$PORT' if boot_launcher?
#
#        release_text
#      end

#      private
#
#      ARGUMENTS_PROPERTY = 'arguments'.freeze
#
#      CLASS_PATH_PROPERTY = 'Class-Path'.freeze
#
#      private_constant :ARGUMENTS_PROPERTY, :CLASS_PATH_PROPERTY
#
#      def release_text
#        [
#          @droplet.environment_variables.as_env_vars,
#          "#{qualify_path @droplet.java_home.root, @droplet.root}/bin/java",
#          @droplet.additional_libraries.as_classpath,
#          @droplet.java_opts.join(' '),
#          main_class,
#          arguments
#        ].flatten.compact.join(' ')
#      end
#
#      def arguments
#        @configuration[ARGUMENTS_PROPERTY]
#      end
#
#      def boot_launcher?
#        main_class =~ /^org\.springframework\.boot\.loader\.(?:[JW]ar|Properties)Launcher$/
#      end
#
#      def main_class
#        JavaBuildpack::Util::JavaMainUtils.main_class(@application, @configuration)
#      end
#
#      def manifest_class_path
#        values = JavaBuildpack::Util::JavaMainUtils.manifest(@application)[CLASS_PATH_PROPERTY]
#        values.nil? ? [] : values.split(' ').map { |value| @droplet.root + value }
#      end

    end

  end
end
