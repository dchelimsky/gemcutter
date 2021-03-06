require 'test_helper'

class RubygemsControllerTest < ActionController::TestCase
  should_forbid_access_when("pushing a gem") { post :create }

  context "When logged in" do
    setup do
      @user = Factory(:email_confirmed_user)
      sign_in_as(@user)
    end

    context "On GET to show for another user's gem" do
      setup do
        @gem = Factory(:rubygem)
        get :show, :id => @gem.to_param
      end

      should_respond_with :success
      should_render_template :show
      should_assign_to :gem
      should "not render edit link" do
        assert_not_contain "Edit Gem"
        assert_have_no_selector "a[href='#{edit_rubygem_path(@gem)}']"
      end
    end

    context "On GET to show for a gem that's hosted" do
      setup do
        @gem = Factory(:rubygem)
        Factory(:version, :rubygem => @gem)
        get :show, :id => @gem.to_param, :format => "json"
      end

      should_assign_to(:gem) { @gem }
      should_respond_with :success
      should "return a json hash" do
        assert_not_nil JSON.parse(@response.body)
      end
    end

    context "On GET to show for a gem that doesn't match the slug" do
      setup do
        @gem = Factory(:rubygem, :name => "ZenTest", :slug => "zentest")
        Factory(:version, :rubygem => @gem)
        get :show, :id => "ZenTest", :format => "json"
      end

      should_assign_to(:gem) { @gem }
      should_respond_with :success
      should "return a json hash" do
        assert_not_nil JSON.parse(@response.body)
      end
    end


    context "On GET to show for a gem that not hosted" do
      setup do
        @gem = Factory(:rubygem)
        assert 0, @gem.versions.count
        get :show, :id => @gem.to_param, :format => "json"
      end

      should_assign_to(:gem) { @gem }
      should_respond_with :not_found
    end

    context "On GET to show for a gem that doesn't exist" do
      setup do
        @name = Factory.next(:name)
        assert ! Rubygem.exists?(:name => @name)
        get :show, :id => @name, :format => "json"
      end

      should_respond_with :not_found
      should "say the rubygem was not found" do
        assert_match /not be found/, @response.body
      end
    end

    context "On GET to show for this user's gem" do
      setup do
        create_gem(@user)
        get :show, :id => @gem.to_param
      end

      should_respond_with :success
      should_render_template :show
      should_assign_to :gem
      should "render edit link" do
        assert_contain "Edit Gem"
        assert_have_selector "a[href='#{edit_rubygem_path(@gem)}']"
      end
    end

    context "On GET to show for a gem that the user is subscribed to" do
      setup do
        @gem = Factory(:rubygem)
        Factory(:version, :rubygem => @gem)
        Factory(:subscription, :rubygem => @gem, :user => @user)
        get :show, :id => @gem.to_param
      end

      should_assign_to(:gem) { @gem }
      should_respond_with :success
      should "have an invisible subscribe link" do
        assert_have_selector "a[style='display:none']", :content => 'Subscribe'
      end
      should "have a visible unsubscribe link" do
        assert_have_selector "a[style='display:block']", :content => 'Unsubscribe'
      end
    end

    context "On GET to show for a gem that the user is not subscribed to" do
      setup do
        @gem = Factory(:rubygem)
        Factory(:version, :rubygem => @gem)
        get :show, :id => @gem.to_param
      end

      should_assign_to(:gem) { @gem }
      should_respond_with :success
      should "have a visible subscribe link" do
        assert_have_selector "a[style='display:block']", :content => 'Subscribe'
      end
      should "have an invisible unsubscribe link" do
        assert_have_selector "a[style='display:none']", :content => 'Unsubscribe'
      end
    end

    context "On GET to edit for this user's gem" do
      setup do
        create_gem(@user)
        get :edit, :id => @gem.to_param
      end

      should_respond_with :success
      should_render_template :edit
      should_assign_to :gem
      should "render form" do
        assert_have_selector "form"
        assert_have_selector "input#linkset_code"
        assert_have_selector "input#linkset_docs"
        assert_have_selector "input#linkset_wiki"
        assert_have_selector "input#linkset_mail"
        assert_have_selector "input#linkset_bugs"
        assert_have_selector "input[type='submit']"
      end
    end

    context "On GET to edit for another user's gem" do
      setup do
        @other_user = Factory(:email_confirmed_user)
        create_gem(@other_user)
        get :edit, :id => @gem.to_param
      end
      should_respond_with :redirect
      should_assign_to(:linkset) { @linkset }
      should_redirect_to('the homepage') { root_url }
      should_set_the_flash_to "You do not have permission to edit this gem."
    end

    context "On PUT to update for this user's gem that is successful" do
      setup do
        @url = "http://github.com/qrush/gemcutter"
        create_gem(@user)
        put :update, :id => @gem.to_param, :linkset => {:code => @url}
      end
      should_respond_with :redirect
      should_redirect_to('the gem') { rubygem_path(@gem) }
      should_set_the_flash_to "Gem links updated."
      should_assign_to(:linkset) { @linkset }
      should "update linkset" do
        assert_equal @url, Rubygem.last.linkset.code
      end
    end

    context "On PUT to update for this user's gem that fails" do
      setup do
        create_gem(@user)
        @url = "totally not a url"
        put :update, :id => @gem.to_param, :linkset => {:code => @url}
      end
      should_respond_with :success
      should_render_template :edit
      should_assign_to(:linkset) { @linkset }
      should "not update linkset" do
        assert_not_equal @url, Rubygem.last.linkset.code
      end
      should "render error messages" do
        assert_contain /error(s)? prohibited/m
      end
    end
  end

  context "On GET to edit without being signed in" do
    setup do
      @rubygem = Factory(:rubygem)
      get :edit, :id => @rubygem.to_param
    end
    should_respond_with :redirect
    should_redirect_to('the homepage') { root_url }
  end

  context "On PUT to update without being signed in" do
    setup do
      @rubygem = Factory(:rubygem)
      put :update, :id => @rubygem.to_param, :linkset => {}
    end
    should_respond_with :redirect
    should_redirect_to('the homepage') { root_url }
  end

  context "On GET to index with no parameters" do
    setup do
      @gems = (1..3).map { |n| Factory(:rubygem, :name => "agem#{n}") }
      Factory(:rubygem, :name => "zeta")
      get :index
    end

    should_respond_with :success
    should_render_template :index
    should_assign_to(:gems) { @gems }
    should "render links" do
      @gems.each do |g|
        assert_contain g.name
        assert_have_selector "a[href='#{rubygem_path(g)}']"
      end
    end
  end

  context "On GET to index as an atom feed" do
    setup do
      @versions = (1..3).map { |n| Factory(:version, :created_at => n.hours.ago) }
      get :index, :format => "atom"
    end

    should_respond_with :success
    should_assign_to(:versions) { @versions }
    should "render posts with titles and links" do
      @versions.each do |v|
        assert_contain v.to_title
        assert_have_selector "link[href='#{rubygem_url(v.rubygem)}']"
      end
    end
  end

  context "On GET to index with a letter" do
    setup do
      @gems = (1..3).map { |n| Factory(:rubygem, :name => "agem#{n}") }
      @zgem = Factory(:rubygem, :name => "zeta")
      get :index, :letter => "z"
    end
    should_respond_with :success
    should_render_template :index
    should_assign_to(:gems) { [@zgem] }
    should "render links" do
      assert_contain @zgem.name
      assert_have_selector "a[href='#{rubygem_path(@zgem)}']"
    end
  end

  context "On GET to show" do
    setup do
      @current_version = Factory(:version)
      @current_dependencies = @current_version.dependencies.runtime
      @gem = @current_version.rubygem
      get :show, :id => @gem.to_param
    end

    should_respond_with :success
    should_render_template :show
    should_assign_to :gem
    should_assign_to(:current_version) { @current_version }
    should_assign_to(:current_dependencies) { @current_dependencies }
    should "render info about the gem" do
      assert_contain @gem.name
      assert_contain @current_version.number
      assert_contain @current_version.created_at.to_date.to_formatted_s(:long)
      assert_not_contain "Versions"
    end
  end

  context "On GET to show with a gem that has multiple versions" do
    setup do
      @gem = Factory(:rubygem)
      @older_version = Factory(:version, :number => "1.0.0", :rubygem => @gem)
      @current_version = Factory(:version, :number => "2.0.0", :rubygem => @gem)
      get :show, :id => @gem.to_param
    end

    should_respond_with :success
    should_render_template :show
    should_assign_to :gem
    should "render info about the gem" do
      assert_contain @gem.name
      assert_contain @current_version.number
      assert_contain @current_version.created_at.to_date.to_formatted_s(:long)

      assert_contain "Versions"
      assert_contain @gem.versions.last.number
      assert_contain @gem.versions.last.created_at.to_date.to_formatted_s(:long)
    end
  end

  context "On GET to show for a gem with no versions" do
    setup do
      @gem = Factory(:rubygem)
      get :show, :id => @gem.to_param
    end
    should_respond_with :success
    should_render_template :show
    should_assign_to :gem
    should "render info about the gem" do
      assert_contain "This gem is not currently hosted on Gemcutter."
    end
  end

  context "On GET to show for a gem with both runtime and development dependencies" do
    setup do
      @version = Factory(:version)

      @development = Factory(:development_dependency, :version => @version)
      @runtime     = Factory(:runtime_dependency,     :version => @version)
      @current_dependencies = @version.dependencies.runtime

      get :show, :id => @version.rubygem.to_param
    end

    should_respond_with :success
    should_render_template :show
    should_assign_to(:current_dependencies) { @current_dependencies }
    should "show runtime dependencies but not development dependencies" do
      assert_contain     @runtime.rubygem.name
      assert_not_contain @development.rubygem.name
    end
  end

  context "with a confirmed user authenticated" do
    setup do
      @user = Factory(:email_confirmed_user)
      @request.env["HTTP_AUTHORIZATION"] = @user.api_key
    end

    context "On POST to create for new gem" do
      setup do
        @request.env["RAW_POST_DATA"] = gem_file.read
        post :create
      end
      should_respond_with :success
      should_assign_to(:_current_user) { @user }
      should_change("the rubygem count") { Rubygem.count }
      should "register new gem" do
        assert_equal @user, Rubygem.last.ownerships.first.user
        assert_equal "Successfully registered gem: test (0.0.0)", @response.body
      end
    end

    context "On POST to create for existing gem" do
      setup do
        rubygem = Factory(:rubygem, :name => "test")
        rubygem.ownerships.create(:user => @user, :approved => true)
        rubygem.versions.create(:number => "0.0.0", :updated_at => 1.year.ago, :created_at => 1.year.ago)
        @request.env["RAW_POST_DATA"] = gem_file("test-1.0.0.gem").read
        post :create
      end
      should_respond_with :success
      should_assign_to(:_current_user) { @user }
      should "register new version" do
        assert_equal @user, Rubygem.last.ownerships.first.user
        assert_equal 1, Rubygem.last.ownerships.size
        assert_equal 2, Rubygem.last.versions.size
        assert_equal "Successfully registered gem: test (1.0.0)", @response.body
      end
    end

    context "On POST to create with bad gem" do
      setup do
        @request.env["RAW_POST_DATA"] = "really bad gem"
        post :create
      end
      should_respond_with :unprocessable_entity
      should_not_change("the rubygem count") { Rubygem.count }
      should "not register gem" do
        assert_match /Gemcutter cannot process this gem/, @response.body
      end
    end

    context "On POST to create for someone else's gem" do
      setup do
        @other_user = Factory(:email_confirmed_user)
        create_gem(@other_user, :name => "test")
        @gem.reload

        @request.env["RAW_POST_DATA"] = gem_file("test-1.0.0.gem").read
        post :create
      end
      should_respond_with 403
      should_assign_to(:_current_user) { @user }
      should "not allow new version to be saved" do
        assert_equal 1, @gem.ownerships.size
        assert_equal @other_user, @gem.ownerships.first.user
        assert_equal 1, @gem.versions.size
        assert_equal "You do not have permission to push to this gem.", @response.body
      end
    end
  end

  context "When not logged in" do
    context "On GET to show for a gem" do
      setup do
        @gem = Factory(:rubygem)
        Factory(:version, :rubygem => @gem)
        get :show, :id => @gem.to_param
      end

      should_assign_to(:gem) { @gem }
      should_respond_with :success
      should "have an subscribe link that goes to the sign in page" do
        assert_have_selector "a[href='#{sign_in_path}']", :content => 'Subscribe'
      end
    end
  end
end

