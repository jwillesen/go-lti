get '/' do
  oauth_creds
  erb :index
end

get '/tool_config.xml' do
  host = request.scheme + "://" + request.host_with_port
  url = host + "/lti_tool"
  tc = IMS::LTI::ToolConfig.new(:title => "Go LTI Provider", :launch_url => url)
  tc.description = "An LTI Provider to embed Go content."

  headers 'Content-Type' => 'text/xml'
  tc.to_xml(:indent => 2)
end

post '/lti_tool' do
  lti_launch
end
