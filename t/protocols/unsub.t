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
      local ppub = require("resty.nats.protocols.unsub")

      local test_cases = {
        { name = "sid = 1, no max messages", input = { sid = 1 }, expected = "UNSUB 1" },
        { name = "sid = 100, no max messages", input = { sid = 100 }, expected = "UNSUB 100" },
        { name = "sid = 1, max messages = 100", input = { sid = 1, max_msgs = 100 }, expected = "UNSUB 1 100" },
      }

      for _, case in ipairs(test_cases) do
        local result = ppub.encode(case.input)
        assert(result == case.expected, "Failed for case: " .. case.name .. ", expected: " .. case.expected .. ", got: " .. result)
      end
    }
  }
