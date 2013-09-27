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
  blank_board
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

post '/save' do
  save_sgf
end

get '/download/:current_user_id/:game_name' do
  download_sgf
end

get '/list' do
  list_files
end

get '/view/:game_name' do
  view_file
end

get '/upload' do
  already_authorized!
  erb :upload_form
end

post '/upload' do
  upload_sgf
end

get '/pwd' do
  Dir.pwd
end
