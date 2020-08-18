require "spec_helper"
require "readme/har_request"

RSpec.describe Readme::HarRequest do
  describe "#as_json" do
    it "builds valid json" do
      request = Readme::HarRequest.new(build_http_request)
      json = request.as_json

      expect(json).to match_json_schema("request")
    end

    it "builds correct values from the http request" do
      http_request = build_http_request(
        url: "https://example.com/api/foo/bar?id=1&name=joel",
        query_params: {"id" => "1", "name" => "joel"},
        cookies: {"cookie1" => "value1", "cookie2" => "value2"},
        headers: {"X-Custom" => "custom", "Authorization" => "Basic abc123"}
      )
      request = Readme::HarRequest.new(http_request)
      json = request.as_json

      expect(json[:method]).to eq http_request.request_method
      expect(json[:url]).to eq "https://example.com/api/foo/bar?id=1&name=joel"
      expect(json[:httpVersion]).to eq http_request.http_version
      expect(json.dig(:postData, :text)).to eq http_request.body
      expect(json.dig(:postData, :mimeType)).to eq http_request.content_type
      expect(json[:headersSize]).to eq(-1)
      expect(json[:bodySize]).to eq http_request.content_length
      expect(json[:headers]).to match_array(
        [
          {name: "Authorization", value: "Basic abc123"},
          {name: "X-Custom", value: "custom"}
        ]
      )
      expect(json[:queryString]).to match_array(
        [
          {name: "id", value: "1"},
          {name: "name", value: "joel"}
        ]
      )
      expect(json[:cookies]).to match_array(
        [
          {name: "cookie1", value: "value1"},
          {name: "cookie2", value: "value2"}
        ]
      )
    end

    it "returns filtered headers and JSON body" do
      http_request = build_http_request(
        content_type: "application/json",
        cookies: {"cookie1" => "value1", "cookie2" => "value2"},
        headers: {
          "X-Custom" => "custom",
          "Authorization" => "Basic abc123",
          "Filtered-Header" => "filtered"
        },
        body: {key1: "key1", key2: "key2"}.to_json
      )
      reject_params = ["Filtered-Header", "key1"]
      request = Readme::HarRequest.new(http_request, Filter.for(reject: reject_params))
      json = request.as_json

      request_body = JSON.parse(json.dig(:postData, :text))
      expect(request_body.keys).to_not include "key1"
      expect(request_body.keys).to include "key2"

      request_headers = json[:headers].map { |pair| pair[:name] }
      expect(request_headers).to_not include "Filtered-Header"
    end

    it "builds proper body when there is no response body" do
      http_request = build_http_request(content_type: nil, body: "")

      request = Readme::HarRequest.new(http_request)
      json = request.as_json

      expect(json).not_to have_key(:postData)
    end
  end

  # if overriding `url` to have query parameters make sure to also override
  # `query_params` with the appropriate hash
  def build_http_request(overrides = {})
    defaults = {
      url: "https://example.com/api/foo/bar?id=1&name=joel",
      query_params: {"id" => "1", "name" => "joel"},
      request_method: "POST",
      http_version: "HTTP/1.1",
      content_length: 6,
      content_type: "application/json",
      cookies: {"cookie1" => "value1", "cookie2" => "value2"},
      headers: {"X-Custom" => "custom", "Authorization" => "Basic abc123"},
      body: {key1: "key1", key2: "key2"}.to_json
    }

    double(:http_request, defaults.merge(overrides))
  end
end
