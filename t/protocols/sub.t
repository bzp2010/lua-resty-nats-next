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
      local ppub = require("resty.nats.protocols.sub")

      local test_cases = {
        { name = "sid = 1, no queue group", input = { subject = "test", sid = 1 }, expected = "SUB test 1" },
        { name = "sid = 100, no queue group", input = { subject = "test", sid = 100 }, expected = "SUB test 100" },
        { name = "sid = 1, with queue group", input = { subject = "test", sid = 1, queue_group = "group1" }, expected = "SUB test group1 1" },
      }

      for _, case in ipairs(test_cases) do
        local result = ppub.encode(case.input)
        assert(result == case.expected, "Failed for case: " .. case.name .. ", expected: " .. case.expected .. ", got: " .. result)
      end
    }
  }
