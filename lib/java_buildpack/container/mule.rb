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
require 'yaml'
require 'java_buildpack/util/qualify_path'
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
        super(context) { |candidate_version| candidate_version.check_size(3) }
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger Mule
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download(@version, @uri) { |file| expand file }
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.environment_variables.add_environment_variable 'MULE_HOME', "$PWD/#{@droplet.sandbox.relative_path_from(@droplet.root)}"
        @droplet.environment_variables.add_environment_variable 'PATH', "$JAVA_HOME/bin:$PATH"
        @droplet.java_opts.add_system_property 'http.port', '$PORT'
                
        [
            @droplet.java_home.as_env_var,
            @droplet.environment_variables.as_env_vars,
            @droplet.java_opts.as_env_var,
            "$PWD/#{@droplet.sandbox.relative_path_from(@droplet.root)}/bin/mule",
            "-M-Dmule.agent.enabled=false",
            "-M-Dhttp.port=$PORT"
         ].flatten.compact.join(' ')
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
          
          #for api gateway, this is not necessary for mule runtimes
          #shell "sed -i #{@droplet.sandbox}/domains/api-gateway/mule-domain-config.xml -e 's/port=\"8081\"/port=\"${http.port}\"/'"

          deploy_app

          configure_memory

        end
      end
                  
      
      def deploy_app
        target = "#{@droplet.sandbox}/apps/app"
        source = "#{@droplet.root}"
        with_timing "Deploying app from #{source} to #{target}" do 
          FileUtils.mkdir_p(target) unless File.exists? target
          Dir.glob("#{source}/**/*").reject{|f| f['.java-buildpack']}.each do |oldfile|
            newfile = target + oldfile.sub(source, '')
            File.file?(oldfile) ? FileUtils.copy(oldfile, newfile) : FileUtils.mkdir(newfile) unless File.exists? newfile
          end
        end
      end

      def configure_memory
          
          mem = ENV['MEMORY_LIMIT']

          @logger.info { "Environment set memory is: #{mem}" }

          #shell "sed -i #{@droplet.sandbox}/conf/wrapper.conf -e 's/initmemory=1024/initmemory=#{mem}/'"
          #shell "sed -i #{@droplet.sandbox}/conf/wrapper.conf -e 's/maxmemory=1024/maxmemory=#{mem}/'"        
      end


    end

  end
end
