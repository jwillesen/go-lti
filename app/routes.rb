get '/' do
  oauth_creds
  erb :index
end

get '/tool_config.xml' do
  tool_config
end

get '/blank' do
  blank_board
end

post '/lti_tool' do
  blank_board(19)
end

post '/editor_button' do
  editor_button
end

get '/embedded_board' do
  embedded_board
end

get '/select_position' do
  select_position
end

get '/edit_board' do
  erb :edit_board
end
