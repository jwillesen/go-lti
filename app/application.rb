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

end
