ActionController::Routing::Routes.draw do |map|
  map.resources :rubygems, :as => "gems", :collection => { :search => :get, :migrate => :get }
  map.root :controller => "home", :action => "index"
  map.sign_up  'sign_up', :controller => 'clearance/users',    :action => 'new'
  map.sign_in  'sign_in', :controller => 'clearance/sessions', :action => 'new'
  map.sign_out 'sign_out',
    :controller => 'clearance/sessions',
    :action     => 'destroy',
    :method     => :delete
end