require 'redis'
require 'redis-namespace'
require 'sinatra/base'
require 'yajl/json_gem'
require 'openssl'

class VideoServer < Sinatra::Base
  enable :logging
  DB = Redis::Namespace.new "video_service", :redis => Redis.new
  set :root, ENV['VIDEO_SERVICE_ROOT'] ||= Dir.pwd

  # Method that will return a token for the given video
  # requires the name or identifier of the video in the parameter
  # video
  # E.X// '/token?video=demo.m4v'
  get '/generate_token' do
    unless params[:video]
      response.status = 400
      content_type :json
      return {"status" => "failed", "notice" => "No video specified you must specify a video"}.to_json
    end
    video_name = params[:video].gsub(/\.\w*/, "")
    token = generate_token(video_name)
    {"status" => "success", 'token' => token}.to_json
  end

  # Executes a sendfile with the video if the given token is valid.
  # Require both token and video as parameters
  # E.X// '/<token>/<filename>.<extension>
  get '/videos/:token.:extension' do
    unless video_name = valid_token(params[:token])
      response.status = 403
      return {"status" => "failed", "notice" => "Invalid token"}.to_json
    end
    send_file File.join(settings.root, "videos", "#{video_name}.#{params[:extension]}")
  end


  # Generate the secure random token and store it in the db 
  # so we can check for token validity later. 
  def generate_token(video_name)
    token = OpenSSL::BN.rand(2*16).to_s(16)
    begin
      DB.set(token, video_name)
      DB.expire token, 300
    rescue
      raise "problem persisting token"
    end
    return token
  end

  #queries the db to determin whether the given token is valid 
  #and matches the given video name
  #returns the name of the video or nil if there is no valid token
  def valid_token(token)
    return nil unless token
    value = DB.get(token)
  end

end
