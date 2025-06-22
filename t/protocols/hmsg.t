use t::Test 'no_plan';

repeat_each();

log_level('info');
no_long_string();
no_shuffle();

add_block_preprocessor(sub {
    my ($block) = @_;

    if (!$block->request) {
        $block->set_value("request", "GET /t");
    }

    if (!$block->no_error_log && !$block->error_log) {
        $block->set_value("no_error_log", "[error]");
    }
});

run_tests();

__DATA__

=== TEST 1: test control line
--- config
  location /t {
    content_by_lua_block {
      local phmsg = require("resty.nats.protocols.hmsg")

      -- HMSG <subject> <sid> [reply-to] <#header bytes> <#total bytes>␍␊[headers]␍␊␍␊[payload]␍␊
      -- subject, sid, reply_to, headers_size, size
      local test_cases = {
        {
          name = "test1", input = "HMSG foo.bar 1 34 45",
          expected = { subject = "foo.bar", sid = "1", reply_to = nil, headers_size = 34, size = 11 },
        },
        {
          name = "test2", input = "HMSG foo.bar 1 48 59",
          expected = { subject = "foo.bar", sid = "1", reply_to = nil, headers_size = 48, size = 11 },
        },
        {
          name = "with reply subject", input = "HMSG FOO.BAR 9 BAZ.69 34 45",
          expected = { subject = "FOO.BAR", sid = "9", reply_to = "BAZ.69", headers_size = 34, size = 11 },
        },
      }

      for _, case in ipairs(test_cases) do
        local result, err = phmsg.decode(case.input)
        if not case.expected_error then
          assert(result ~= nil, "Failed for case: " .. case.name .. ", error: " .. (err or "nil"))
          for k, v in pairs(case.expected) do
            assert(result[k] == v, "Failed for case " .. k .. ": " .. case.name .. ", expected: " .. k .. " = " .. tostring(v) .. ", got: " .. tostring(result[k]))
          end
        else
          assert(err == case.expected_error, "Expected error: " .. case.expected_error .. ", got: " .. (err or "nil"))
        end
      end
    }
  }



=== TEST 2: test headers
--- config
  location /t {
    content_by_lua_block {
      local phmsg = require("resty.nats.protocols.hmsg")

      local test_cases = {
        {
          name = "test1", input = "NATS/1.0\r\nFoodGroup: vegetable",
          expected = { FoodGroup = "vegetable" }
        },
        {
          name = "test2", input = "NATS/1.0\r\nFoodGroup: vegetable\r\nFood: Carrot",
          expected = { FoodGroup = "vegetable", Food = "Carrot" }
        },
        {
          name = "with extra spaces", input = "NATS/1.0\r\n FoodGroup: vegetable",
          expected = { FoodGroup = "vegetable" }
        },
        {
          name = "no header value", input = "NATS/1.0\r\nFoodGroup: ",
          expected = { FoodGroup = "" }
        },
      }

      for _, case in ipairs(test_cases) do
        local headers, err = phmsg.decode_headers(case.input)
        if not case.expected_error then
          assert(headers ~= nil, "Failed for case: " .. case.name .. ", error: " .. (err or "nil"))          
          for k, v in pairs(case.expected) do
            assert(headers[k] == v, "Failed for case: " .. case.name .. ", expected: " .. k .. " = " .. tostring(v) .. ", got: " .. tostring(headers[k]))
          end
        else
          assert(err == case.expected_error, "Expected error: " .. case.expected_error .. ", got: " .. (err or "nil"))
        end
      end
    }
  }
