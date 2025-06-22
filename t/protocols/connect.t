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
      local pconnect = require("resty.nats.protocols.connect")

      local test_cases = {
        { name = "test", input = { test1 = "test1" }, expected = 'CONNECT {"test1":"test1"}' },
      }

      for _, case in ipairs(test_cases) do
        local result = pconnect.encode(case.input)
        assert(result == case.expected, "Failed for case: " .. case.name .. ", expected: " .. case.expected .. ", got: " .. result)
      end
    }
  }
