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

=== TEST 1: test
--- config
  location /t {
    content_by_lua_block {
      local pinfo = require("resty.nats.protocols.info")

      -- INFO {"option_name":option_value,...}␍␊
      local test_cases = {
        { name = "test1", input = 'INFO {"test1":"test1","test2":"test2"}', expected = { test1 = "test1", test2 = "test2" } },
      }

      for _, case in ipairs(test_cases) do
        local result, err = pinfo.decode(case.input)
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
