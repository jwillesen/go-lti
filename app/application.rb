class GoLtiApplication < Sinatra::Application

  def oauth_creds
    @oauth_creds ||= {"go" => "secret"}
  end

  def show_error(msg)
    @message = msg
    erb :error
  end

  def valid_request_time?
    Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i < 60*60
  end

  def valid_nonce?
    return true
  end

  def authorize_with_hash!(args)
    key = args['oauth_consumer_key']
    secret = oauth_creds[key]
    unless key && secret
      @tp = IMS::LTI::ToolProvider.new(nil, nil, args)
      @tp.lti_msg = "authorization error"
      @tp.lti_errorlog = "authorization error"
      return show_error "authorization error at #{__FILE__}:#{__LINE__}"
    end
    @tp = IMS::LTI::ToolProvider.new(key, secret, args)

    # success
    nil
  end

  def authorize!
    err = authorize_with_hash!(params)
    return err if err

    # these checks should also happen in already_authorized! ???
    return show_error "invalid request" unless @tp.valid_request?(request)
    return show_error "expired request" unless valid_request_time?
    return show_error "nonce error" unless valid_nonce?

    # everything's ok, store launch in the session
    session['launch_params'] = @tp.to_params
    nil
  end

  def already_authorized!
    launch_params = session['launch_params']
    return show_error unless launch_params
    # probably should do some other checks on the session, to make sure it's still valid

    err = authorize_with_hash!(launch_params)
    return err if err

    # any other checks should go here too? timeout check?

    # ok, authorized
    nil
  end

  def current_user_id
    @tp.user_id
  end

  def for_embedding?
    session['launch_params']['ext_content_intended_use'] == 'embed'
  end

  def for_launch_link?
    session['launch_params']['ext_content_return_types'] =~ /lti_launch_url/
  end

  def lti_launch
    err = authorize!
    return err if err

    "lti launch successful!"
  end

  def blank_board(board_size = nil)
    if params[:other_user_id] && params[:game_name]
      return launch_view_user_file
    end

    err = authorize!
    return err if err
    erb :blank
  end

  def content_redirect(options)
    launch_params = session['launch_params']
    target_url = launch_params['ext_content_return_url'] || launch_params['launch_presentation_return_url']
    return show_error("no return url specified") unless target_url
    redirect target_url + "?" + ::URI.encode_www_form(options)
  end

  def editor_button
    err = authorize!
    return err if err

    return show_error "embedded use expected" unless params['ext_content_intended_use'] = 'embed'
    return show_error "embedded iframe expected" unless params['ext_content_return_types'].include?('iframe')

    #erb :edit_board
    erb :blank
  end

  def embedded_sgf_url
    "#{root_url}/download/#{params[:user_id]}/#{params[:game_name]}"
    #root_url + "/sgf/blood_vomit.sgf"
  end

  def load_path
    return nil unless params[:load_path] =~ /(\d+(,\d+)+)/
    params[:load_path]
    # num_csv = $1
    # num_strs = num_str.split(',')
    # nums = num_strs.map(&:to_i)
  end

  def choose_responder
    case session['launch_params']['ext_content_return_types']
    when /iframe/
      'embed'
    when /lti_launch_url/
      'view'
    else
      'embed'
    end
  end

  def choose_content_params(url)
    result = {url: url}.merge case session['launch_params']['ext_content_return_types']
    when /iframe/ then {
      return_type: 'iframe',
      width: 423,
      height: 535,
    }
    when /lti_launch_url/ then {
      return_type: 'lti_launch_url',
    }
    else {
      return_type: 'insert_error_here',
    }
    end
    result
  end

  def select_launch_position
    err = already_authorized!
    return err if err

    responder = choose_responder
    launch_url = root_url + "/lti_tool"
    launch_url_params = params.select { |k, v| ['game_name', 'load_path'].include?(k) }
    launch_url_params['other_user_id'] = @tp.user_id
    unless launch_url_params.empty?
      # the url parameter gets encoded later, so don't encode it here or it will be double encoded
      launch_url_assignments = launch_url_params.map { |k,v| "#{k}=#{v}" }
      launch_url += "?" + launch_url_assignments.join('&')
    end

    content_params = choose_content_params(launch_url)
    content_redirect(content_params)
  end

  def select_position
    err = already_authorized!
    return err if err

    responder = choose_responder
    embed_url = root_url + "/#{responder}/#{current_user_id}/#{params[:game_name]}"
    embed_url_params = params.select { |k, v| ['load_path'].include?(k) }
    unless embed_url_params.empty?
      # the url parameter gets encoded later, so don't encode it here or it will be double encoded
      embed_url_assignments = embed_url_params.map { |k,v| "#{k}=#{v}" }
      embed_url += "?" + embed_url_assignments.join('&')
    end

    content_params = choose_content_params(embed_url)
    content_redirect(content_params)
  end

  def embedded_board
    erb :embedded_board
  end

  def root_url
    host = request.scheme + "://" + request.host_with_port
  end

  def save_dir(user_id)
    "saves/#{user_id}"
  end

  def save_sgf_file_to_disk(game_name, sgf)
    uuid = SecureRandom.uuid
    dir_name = save_dir(@tp.user_id)
    file_name = "#{game_name}___#{uuid}.sgf"
    FileUtils.mkdir_p dir_name
    File.open("#{dir_name}/#{file_name}", "wb") do |file|
      file.write(sgf)
    end

    file_name
  end

  def save_sgf
    err = already_authorized!
    return err if err

    game_name = params[:game_name]
    sgf = params[:sgf]
    return show_error "missing sgf parameter" unless sgf
    return show_error "missing gamaname parameter" unless game_name

    file_name = save_sgf_file_to_disk(game_name, sgf)
    file_name
  end

  def upload_sgf
    err = already_authorized!
    return err if err

    game_name = params[:game_name]
    sgf = params[:sgf]
    sgf_tempfile = sgf[:tempfile]

    return show_error('missing game_name') unless game_name
    return show_error('missing sgf') unless sgf
    return show_error('incorrect type for sgf') unless sgf_tempfile

    file_name = save_sgf_file_to_disk(game_name, sgf_tempfile.read)
    redirect "/view/#{file_name}"
  end


  def download_sgf
    return show_error('missing current_user_id') unless params[:current_user_id]
    return show_error('missing game_name') unless params[:game_name]
    dir_name = save_dir(params[:current_user_id])
    game_name = params[:game_name]
    path = "#{dir_name}/#{game_name}"
    return 404 unless File.exist?(path)
    File.read(path)
  end

  def user_files
    Dir.glob("#{save_dir(@tp.user_id)}/*.sgf").map {|f| File.basename(f) }
  end

  def list_files
    err = already_authorized!
    return err if err

    erb :list_files
  end

  def launch_view_user_file
    err = authorize!
    return err if err

    other_user_id = params[:other_user_id]
    game_name = params[:game_name]
    return show_error('missing other_user_id') unless other_user_id
    return show_error('missing game_name') unless game_name

    @view_file_game_name = game_name
    @view_file_url = "/download/#{other_user_id}/#{game_name}"
    erb :blank
  end

  def view_file
    err = already_authorized!
    return err if err
    return show_error('missing game_name') unless params[:game_name]

    dir_name = save_dir(@tp.user_id)
    game_name = params[:game_name]
    path = "#{dir_name}/#{game_name}"
    return 404 unless File.exist?(path)

    @view_file_game_name = game_name
    @view_file_url = "/download/#{@tp.user_id}/#{game_name}"
    erb :blank
  end

  def view_file_url
    @view_file_url || "/sgf/blank-19.sgf"
  end

  def view_file_game_name
    @view_file_game_name || "null"
  end

  def tool_config
    launch_url = root_url + "/lti_tool"
    tc = IMS::LTI::ToolConfig.new(:title => "Go LTI Provider", :launch_url => launch_url)
    tc.extend(IMS::LTI::Extensions::Canvas::ToolConfig)
    tc.description = "An LTI Provider to embed Go content."

    tc.canvas_course_navigation!({url: launch_url, text: "Go Board", visibility: "members"})
    tc.canvas_resource_selection!({
      url: launch_url,
      icon_url: root_url + "/images/go-icon.png",
      text: "go selection",
      selection_width: 200,
      selection_height: 200,
      enabled: true,
    })
    tc.canvas_editor_button!({
      url: launch_url,
      icon_url: root_url + "/images/go-icon.png",
      text: "go selection",
      selection_width: 830,
      selection_height: 710,
      enabled: true,
    })

    headers 'Content-Type' => 'text/xml'
    tc.to_xml(:indent => 2)
  end

end
