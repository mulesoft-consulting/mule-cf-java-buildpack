require 'json'
require 'fileutils'
require 'open3'

#parse the VCAP APPLICATION ENV VAR SO WE HAVE THE INFO WE NEED
appData = JSON.parse(ENV['VCAP_APPLICATION'])

#todo read variables from environment
USER = ENV['ANYPOINT_USERNAME']
PASS = ENV['ANYPOINT_PASSWORD']
ANYPOINT = ENV['ANYPOINT_ARM_HOST']
ENVIRONMENT = ENV['ANYPOINT_ENVIRONMENT']
SERVER_NAME = "#{appData['application_name']}#{ENV['CF_INSTANCE_INDEX']}"
JAVA_HOME = ENV['JAVA_HOME']
ANYPOINT_ON_PREM = ENV['ANYPOINT_ARM_ONPREM']

SCRIPT_FOLDER = File.expand_path(File.dirname(__FILE__))

#utility function
def shell(*args)
	Open3.popen3(*args) do |_stdin, stdout, stderr, wait_thr|
		while line = stdout.gets
	    	puts line
	  	end
		if wait_thr.value != 0
		  puts "\nCommand '#{args.join ' '}' has failed"
		  puts "STDOUT: #{stdout.gets nil}"
		  puts "STDERR: #{stderr.gets nil}"

		  fail
		end
	end
end

def register
	puts "Logging into the platform..."

	json = `curl -k -s -X POST 'https://#{ANYPOINT}/accounts/login?username='#{USER}'&password='#{PASS}`

	if json.eql? "Unauthorized"
		puts "Authentication failed..."
		exit 1
	end

	#parse the response.
	json = JSON.parse(json)

	#this is the access token for the API
	access_token = json['access_token']

	#build a header for the token
	token_header = "-H \"Authorization: Bearer #{access_token}\""



	#learn which is the organization ID of the current user
	puts "Getting the current org id..."
	json = `curl -k -s -X GET #{token_header} https://#{ANYPOINT}/accounts/api/me`

	json = JSON.parse(json)

	org_id =  json['user']['organization']['id']

	#build a header for the organization id
	org_header = "-H \"X-ANYPNT-ORG-ID: #{org_id}\""

	#get the current environement id.
	puts "Getting the id for the selected environment..."
	json = `curl -k -s -X GET #{token_header} https://#{ANYPOINT}/accounts/api/organizations/#{org_id}/environments`

	json = JSON.parse(json)

	env_id = nil

	json['data'].each do |env| 
		if env['name'].eql? ENVIRONMENT
			env_id = env['id']
			break
		end
	 end

	#build a header for the environment id.
	env_header = "-H \"X-ANYPNT-ENV-ID: #{env_id}\""


	########## At this point we can check if the server exists and if it does, delete it. #######
	puts "Looking for servers with the same name..."

	json = `curl -k -s -X GET #{token_header} #{org_header} #{env_header} https://#{ANYPOINT}/hybrid/api/v1/servers`


	json = JSON.parse(json)

	json['data'].each do |srv|
	    
	    if srv['name'].eql? SERVER_NAME
	        puts "Found server with name: #{SERVER_NAME}, attempting to clear it ..."
	        `curl -k -s -X DELETE #{token_header} #{org_header} #{env_header} https://#{ANYPOINT}/hybrid/api/v1/servers/#{srv['id']}`
	        break
	    end
	end

	###### At this point we can get the registration token #######
	puts "Getting registration token..."
	json = `curl -k -s -X GET #{token_header} #{org_header} #{env_header} https://#{ANYPOINT}/hybrid/api/v1/servers/registrationToken`

	json = JSON.parse(json)

	reghash = json['data']

	#Run the server registration script...
	if ANYPOINT_ON_PREM.nil? || ANYPOINT_ON_PREM.empty?

	  cmd = [
	      "export",
	      "JAVA_HOME=#{JAVA_HOME}",
	      "&&",
	      "#{SCRIPT_FOLDER}/amc_setup",
	      "-H",
	      reghash,
	      "#{SERVER_NAME}"
	    ].flatten.compact.join(' ')
	else
	    #this is the command that needs to be used with arm on prem
	    cmd = [
	        "export",
	        "JAVA_HOME=#{JAVA_HOME}",
	        "&&",
	        "#{SCRIPT_FOLDER}/amc_setup",
	        "-A http://#{ANYPOINT}:8080/hybrid/api/v1",
	        "-W \"wss://#{ANYPOINT}:8443/mule\"",
	        "-F https://#{ANYPOINT}/apiplatform",
	        "-C https://#{ANYPOINT}/accounts",
	        "-H",
	        reghash,
	        "#{SERVER_NAME}"
	      ].flatten.compact.join(' ')
	end

	puts "Running registration..."
	puts `#{cmd}`
end

def run
	################### FINALLY RUN THE MULE #####################
	
	mem = ENV['MEMORY_LIMIT'].chomp("m").to_i / 2


	cmd = [
	    "export",
	    "JAVA_HOME=#{JAVA_HOME}",
	    "&&",
		"#{SCRIPT_FOLDER}/mule",
	    "wrapper.java.maxmemory=#{mem}",
	    "wrapper.java.initmemory=#{mem}",
	    "-M-Dmule.agent.enabled=false",
	    "-M-Dhttp.port=$PORT"
	 ].flatten.compact.join(' ')

	puts "Running mule..."
	puts cmd
	shell cmd
end



if !ANYPOINT.nil?
	register
end

run