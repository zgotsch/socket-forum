require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'data_mapper'
require 'bcrypt'
require 'digest/sha2'

require 'json'

hmac_secret = ''
File.open('shared_secret.key', 'r') do |f|
	hmac_secret = f.read.strip
end

def hmac(message, secret)
	inner_padding = 0x8d
	outer_padding = 0x94

	zero_padded_secret = secret.ljust(256, 0.chr).chars

	inner_key = zero_padded_secret.map { |x| (x.ord ^ inner_padding).chr }.join
	outer_key = zero_padded_secret.map { |x| (x.ord ^ outer_padding).chr }.join

	inner_hash = Digest::SHA2.new.update(inner_key + message).to_s
	return Digest::SHA2.new.update(outer_key + inner_hash).to_s
end

DataMapper.setup(:default, "sqlite:./project.db")

class Forum
	include DataMapper::Resource

	property :id,			Serial
	property :title,		String
	property :created_at,	DateTime

	has n, :topics
end

class Topic
	include DataMapper::Resource

	property :id,			Serial
	property :title,		String
	property :created_at,	DateTime

	belongs_to :forum
	has n, :posts
end

class Post
	include DataMapper::Resource
	
	property :id,			Serial
	property :body,			Text
	property :created_at,	DateTime

	belongs_to :topic
	belongs_to :author, 'User'
end

class User
	include DataMapper::Resource

	property :id,				Serial
	property :salt,				String
	property :hashed_password,	String, :length=>512
	property :email,			String
	property :name,				String
end

DataMapper.finalize

DataMapper.auto_migrate!

Sinatra::Application.reset!

@f = Forum.create(:title=>"Zach's awesome forum")
@topic = Topic.create(
	:title => "Berkeley Hack Group",
	:created_at => Time.now
)
@f.topics << @topic
@f.save
@u = User.create(:salt=>'asdf', :hashed_password=>'asdf', :email=>'asdf', :name=>'ZG')
@p = Post.create(:body=>"First post ever. Infinity fake internet points to me!", :created_at=>Time.now)
@p.author = @u
@p.save
@topic.posts << @p
@topic.save

enable :sessions

def current_user
	User.get(session[:current_user])
end

#User management
white_list = ['/signup', '/login', '/logout']
before do
	puts current_user.inspect
	if current_user == nil
		unless white_list.include? request.path_info
			redirect to('/login')
		end
	end
end

get '/signup' do
	erb :signup
end
post '/signup' do
	salt = BCrypt::Engine.generate_salt
	hash = BCrypt::Engine.hash_secret(params[:password], salt)

	new_user = User.create(
		:email => params[:email],
		:salt => salt,
		:hashed_password => hash,
		:name => params[:name],
	)
	session[:current_user] = new_user.id

	redirect to('/')
end

get '/login' do
	erb :login
end
post '/login' do
	if user = User.first(:email => params[:email])
		if user.hashed_password == BCrypt::Engine.hash_secret(params[:password], user.salt)
			session[:current_user] = user.id
			redirect to('/')
		end
	end
	"Invalid credentials"
end

get '/logout' do
	session[:current_user] = nil
	redirect to('/')
end
#End user management

get '/' do
	redirect to('/forums/')
end

get '/forums/' do
	@title = "Forums"
	erb :forum_list, :locals => {:forums => Forum.all}
end

get '/forums/:forum_id' do
	if forum = Forum.get(params[:forum_id])
		"you made it to #{forum.title}"
		erb :forum, :locals => {:forum => forum}
	else
		"Forum not found!"
	end
end

get '/forums/:forum_id/topics/:topic_id' do
	@title = 'Error'
	if forum = Forum.get(params[:forum_id])
		if topic = forum.topics.get(params[:topic_id])
			@title = topic.title
			@scripts = ['post_update.js']
			erb :topic, :locals => {:forum => forum, :topic => topic}
		else
			"Error: Topic doesn't exist in this forum"
		end
	else
		"Error: Forum doesn't exist!"
	end
end

post '/forums/:forum_id/topics/:topic_id' do
	@title = 'Error'
	if forum = Forum.get(params[:forum_id])
		if topic = forum.topics.get(params[:topic_id])
			new_post = Post.new(:body => params[:post][:new_post], :created_at => Time.now)
			topic.posts << new_post
			new_post.author = current_user
			new_post.save
			post_html = erb :post, :locals => {:post => new_post}, :layout => false
			'{"status": "success",' +
			' "post": {"html": "' + post_html + '",' +
					 ' "auth": "' + hmac(new_post.body, hmac_secret) + '"}' +
			'}'
			JSON.generate({:status => "success",
						   :post => {:html => post_html,
									 :auth => hmac(post_html, hmac_secret)}})
		else
			'{"status": "fail", "message": "Topic doesn\'t exist in this forum"}'
		end
	else
		'{"status": "fail", "message": "Forum doesn\'t exist"}'
	end
end

