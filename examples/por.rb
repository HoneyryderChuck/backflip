require 'sidekiq'
require 'backflip'

# If your client is single-threaded, we just need a single connection in our Redis connection pool
Sidekiq.configure_client do |config|
  config.redis = { :url => "redis://127.0.0.1:6379/4/", :namespace => 'x', :size => 1 }
end

# Sidekiq server is multi-threaded so our Redis connection pool size defaults to concurrency (-c)
Sidekiq.configure_server do |config|
  config.redis = { :url => "redis://127.0.0.1:6379/4/", :namespace => 'x' }
end

# Start up sidekiq via
# ./bin/sidekiq -r ./examples/por.rb
# and then you can open up an IRB session like so:
# irb -r ./examples/por.rb
# where you can then say
# PlainOldRuby.perform_async "like a dog", 3
#
class PlainOldRuby
  include Backflip::Job

  def perform(how_hard="super hard", how_long=1)
#    sleep how_long
    puts "Workin' #{how_hard}"
  end
end
