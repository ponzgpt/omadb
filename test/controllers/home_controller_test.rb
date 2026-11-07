require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "home renders the layer counters and health answers" do
    get root_path
    assert_response :success
    assert_select ".counters", /0 verified/
    get "/healthz"
    assert_response :success
  end
end
