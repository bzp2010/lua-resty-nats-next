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
      local ppub = require("resty.nats.protocols.pub")

      local test_cases = {
        { name = "no reply to, no payload", input = { subject = "test" }, expected = "PUB test 0\r\n" },
        { name = "no reply to, with payload", input = { subject = "test", payload = "helloworld" }, expected = "PUB test 10\r\nhelloworld" },
        { name = "with reply to, no payload", input = { subject = "test", reply_to = "replySubject" }, expected = "PUB test replySubject 0\r\n" },
        { name = "with reply to, with payload", input = { subject = "test", reply_to = "replySubject", payload = "helloworld" }, expected = "PUB test replySubject 10\r\nhelloworld" },
      }

      for _, case in ipairs(test_cases) do
        local result = ppub.encode(case.input)
        assert(result == case.expected, "Failed for case: " .. case.name .. ", expected: " .. case.expected .. ", got: " .. result)
      end
    }
  }
