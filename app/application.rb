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

  def authorize!
    key = params['oauth_consumer_key']
    secret = oauth_creds[key]
    unless key && secret
      @tp = IMS::LTI::ToolProvider.new
      @tp.lti_msg = "authorization error"
      @tp.lti_errorlog = "authorization error"
      return show_error "authorization error"
    end
    @tp = IMS::LTI::ToolProvider.new(key, secret, params)

    return show_error "invalid request" unless @tp.valid_request?(request)
    return show_error "expired request" unless valid_request_time?
    return show_error "nonce error" unless valid_nonce?

    # everything's ok
    nil
  end

  def lti_launch
    err = authorize!
    return err if err

    "lti launch successful!"
  end

  def blank_board(board_size = nil)
    @board_size ||= board_size
    @board_size ||= params[:board_size]
    @board_size ||= 19
    erb :blank
  end

  def content_redirect(options)
    target_url = params['ext_content_return_url'] || params['launch_presentation_return_url']
    return show_error("no return url specified") unless target_url
    redirect target_url + "?" + ::URI.encode_www_form(options)
  end

  def editor_button
    err = authorize!
    return err if err

    return show_error "embedded use expected" unless params['ext_content_intended_use'] = 'embed'
    return show_error "embedded iframe expected" unless params['ext_content_return_types'].include?('iframe')

    content_redirect(
      return_type: 'iframe',
      url: root_url + "/compact_board",
      width: 423,
      height: 535,
    )
  end

  def root_url
    host = request.scheme + "://" + request.host_with_port
  end

  def sgf_url
    root_url + "/sgf/blood_vomit.sgf"
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
      selection_width: 200,
      selection_height: 200,
      enabled: true,
    })

    headers 'Content-Type' => 'text/xml'
    tc.to_xml(:indent => 2)
  end

end
