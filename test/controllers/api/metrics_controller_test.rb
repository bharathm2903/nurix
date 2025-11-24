require "test_helper"

class Api::MetricsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_metrics_index_url
    assert_response :success
  end
end
