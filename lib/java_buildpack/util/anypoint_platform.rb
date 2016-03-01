# Encoding: utf-8
# Mulesoft Cloud foundry Build Pack
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

require 'java_buildpack/util'
require 'pathname'
require 'json'
require 'net/http'
require 'net/https'
require 'uri'
require 'java_buildpack/logging/logger_factory'

module JavaBuildpack
  module Util

    # A module encapsulating all of the utility components for caching
    module AnypointPlatform

    	class Connection

    		def initialize(host, user, password, environment)
	    		@host = host
	    		@username = user
	    		@password = password
	    		@environment = environment
	    		@logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger AnypointPlatform
	    		configureHttp
    		end
    		
    		def configureHttp
    			
    			endpoint = "https://#{@host}"

    			uri = URI.parse(endpoint)
				
				@http = Net::HTTP.new(uri.host, uri.port)
				@http.use_ssl = true
				@http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    		end

    		#login into the anypoint platform to get an access token so apis may be called
    		def login
    			@logger.info { "Getting access token for the anypoint platform: #{@host}" }

    			loginPath = "/accounts/login?username=#{@username}&password=#{@password}"

    			request = Net::HTTP::Post.new(loginPath)
				response = @http.request(request)

				jsonData = JSON.parse(response.body)

				@logger.debug { "Access token : #{jsonData['access_token']}" }

				@accesstoken = jsonData['access_token']
    		end


    		def get_registration_hash

    			orgId = get_org_id
    			envId = get_env_id(orgId)
				
    			@logger.info { " OrgId: #{orgId} \n EnvId: #{envId}"}

    			userInfoPath = "/hybrid/api/v1/servers/registrationToken"

    			headers = authHeader
    			headers['X-ANYPNT-ENV-ID'] = envId
    			headers['X-ANYPNT-ORG-ID'] = orgId

    			request = Net::HTTP::Get.new(userInfoPath, headers)
    			response = @http.request(request)

    			jsonData = JSON.parse(response.body)

    			return jsonData['data']
    		end


            def remove_server(name)

                @logger.info { "Attempting to remove server: #{name}..." }

                serversPath = "/hybrid/api/v1/servers"

                orgId = get_org_id
                envId = get_env_id(orgId)
                
                @logger.info { " OrgId: #{orgId} \n EnvId: #{envId}"}

                headers = authHeader
                headers['X-ANYPNT-ENV-ID'] = envId
                headers['X-ANYPNT-ORG-ID'] = orgId

                request = Net::HTTP::Get.new(serversPath, headers)

                response = @http.request(request)

                jsonData = JSON.parse(response.body)

                jsonData['data'].each do |srv|
                    
                    if srv['name'].eql? name
                        @logger.info { "Found server with name: #{name}, attempting to clear it ..."}
                        path = "#{serversPath}/#{srv['id']}"

                        request = Net::HTTP::Delete.new(path, headers)

                        response = @http.request(request)

                        if response.code.eql? '204'
                            @logger.info { "Found and deleted server with name: #{name}" }
                        end
                    end
                end
            end

    		#api call for getting the user's organization id
    		def get_org_id

    			userInfoPath = "/accounts/api/me"

    			request = Net::HTTP::Get.new(userInfoPath, authHeader)

    			response = @http.request(request)

    			jsonData = JSON.parse(response.body)

    			return jsonData['user']['organization']['id']
    		end

    		#api call for getting the selected environment id
    		def get_env_id(orgId)

    			userInfoPath = "/accounts/api/organizations/#{orgId}/environments"

    			request = Net::HTTP::Get.new(userInfoPath, authHeader)

    			response = @http.request(request)

    			jsonData = JSON.parse(response.body)

    			jsonData['data'].each do |env| 
    				if env['name'].eql? @environment
    					return env['id']
    				end
    			 end

    			return envid
    		end


    		def authHeader 
    			return {
    				"Authorization" => "Bearer #{@accesstoken}"
    			}
    		end

    	end


    end

  end
end