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
      local perr = require("resty.nats.protocols.err")

      local test_cases = {
        { name = "test1", input = "-ERR 'Unknown Protocol Operation'", expected = { payload = "Unknown Protocol Operation" } },
        { name = "test2", input = "-ERR 'Attempted To Connect To Route Port'", expected = { payload = "Attempted To Connect To Route Port" } },
        { name = "test3", input = "-ERR 'Secure Connection - TLS Required'", expected = { payload = "Secure Connection - TLS Required" } },
        { name = "test4", input = "-ERR 'Slow Consumer'\r\nNOT_COMMAND", expected = { payload = "Slow Consumer" } },
        { name = "test5", input = "-ERR ''", expected_error = "failed to decode message: unknown error" },
        { name = "test6", input = "-ERR 'test'\r\nNOT_COMMAND", expected = { payload = "test" } },
      }

      for _, case in ipairs(test_cases) do
        local result, err = perr.decode(case.input)
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
