require 'halcyon'

# = Required Libraries
%w().each {|dep|require dep}

# = Configuration
Halcyon.config.use do |c|
  c[:allow_from] = :all
  c[:logging] = {
    :type => 'Logger',
    # :file => nil, # nil is STDOUT
    :level => 'debug'
  }
end

# = Routes
Halcyon::Application.route do
  match('/returner').to(:controller => 'application', :action => 'returner')
  match('/time').to(:controller => 'application', :action => 'time')
  
  match('/').to(:controller => 'application', :action => 'index')
  
  # failover
  {:action => 'not_found'}
end

# = Hooks
Halcyon::Application.startup do |config|
  logger.info 'Define startup tasks in Halcyon::Application.startup {}'
end

# = Application
class Application < Halcyon::Controller
  
  def index
    ok('Nothing here')
  end
  
  def time
    ok(Time.now.to_s)
  end
  
  # Returns exactly what it gets in terms of params
  def returner
    ok params
  end
  
end
