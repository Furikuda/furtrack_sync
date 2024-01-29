#!/usr/bin/ruby

require "json"
require "mini_exiftool"
require "nokogiri"
require "net/http"
require "jwt"

$dest_folder = "saved_photos"


class Furtrack
  def initialize(email:, password:, force: false)
    @email = email
    @password = password
    @x_api_key = nil
    @authorization = nil
    @http = Net::HTTP.new("solar.furtrack.com", 443)
    @http.use_ssl = true
    @force =  force
  end

  def login
    js_path = Nokogiri::HTML.parse(Net::HTTP.get(URI.parse("https://www.furtrack.com"))).css('script').select{|s|(s['src']||'').start_with?("/static/js/main")}[0]['src']
    js_text = Net::HTTP.get(URI.parse("https://www.furtrack.com/#{js_path}"))
    jwt_key = js_text.scan(/jwtKey:"([^"]+)"/)[0][0]

	jwt_headers = {'alg': 'HS256', 'typ': 'JWT'}
    jwt_payload= {'iat': Time.now.to_i, 'exp': Time.now().to_i + (60*60), 'purpose': 3 }
    req = Net::HTTP::Post.new("/user/login")
    req['Content-Type'] = 'application/json'
    @x_api_key = JWT.encode(jwt_payload, jwt_key, algorithm='HS256', header_fields=jwt_headers)
    req['x-api-key'] = @x_api_key
    data = {
      'password' => @password,
      'email' => @email
    }
    req.body = data.to_json
    res = @http.request(req)
    j_resp = JSON.parse(res.body)
    if not j_resp['success']
      raise "Login failed"
    end
    @authorization = 'Bearer '+j_resp['token']
  end

  def get_feed()
    login if not @authorization
    req = Net::HTTP::Get.new("/view/feed")
    req['Authorization'] = @authorization
    res = @http.request(req)
    return JSON.parse(res.body)
  end

  def get_post_image(post_stub:)
    url = "https://orca.furtrack.com/gallery/sample/#{post_stub}.jpg"
    puts "Pulling image #{url}" if $DEBUG
    pic_data = Net::HTTP.get(URI.parse(url))
    return pic_data
  end

  def get_post(post_id:)
    req = Net::HTTP::Get.new("https://solar.furtrack.com/get/p/#{post_id}")
    res = @http.request(req)
    metadata = JSON.parse(res.body)
    raise Exception.new("Error getting post metadata #{post_id}") if not metadata['success']
    return metadata
  end

  def save_post_with_metadata(post_id:)
    metadata = get_post(post_id: post_id)
    filename = File.join($dest_folder, metadata['post']["postStub"]+".jpg")
    if File.exist?(filename) and not @force
      puts "Skipping postId #{post_id} since file #{filename} is already present. Pass force:true to Furtrack class if you want to force overwrite"
      return
    end
    file = File.new(filename, 'w')
    file.write(get_post_image(post_stub: metadata["post"]["postStub"]))
    file.close
    photo = MiniExiftool.new(filename)
    photo.user_comment = JSON.dump(metadata)
    photo.save
    puts "Saved #{filename}"
  end

  def save_all_from_feed()
    get_feed["posts"].each do |post|
      post_id = post["postId"]
      save_post_with_metadata(post_id:post_id)
    end
  end
end

if not File.exist?("creds.json")
  raise Exception.new("Please put your credentials in creds.json (see README)")
end
creds = JSON.load(File.read("creds.json"))
f = Furtrack.new(email: creds["email"], password: creds["password"])
f.save_all_from_feed()
