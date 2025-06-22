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
      local pmsg = require("resty.nats.protocols.msg")

      -- MSG <subject> <sid> [reply-to] <#bytes>␍␊[payload]␍␊
      -- subject, sid, reply_to, size, pos
      local test_cases = {
        { name = "test1", input = "MSG foo.bar 1 10", expected = { subject = "foo.bar", sid = "1", reply_to = nil, size = 10 } },
        { name = "test2", input = "MSG foo.bar 1 replySubject 10", expected = { subject = "foo.bar", sid = "1", reply_to = "replySubject", size = 10 } },
        { name = "test3", input = "MSG foo.bar 100 replySubject 10", expected = { subject = "foo.bar", sid = "100", reply_to = "replySubject", size = 10 } },
        { name = "test4", input = "MSG foo.bar 100 5432", expected = { subject = "foo.bar", sid = "100", size = 5432 } },
      }

      for _, case in ipairs(test_cases) do
        local result, err = pmsg.decode(case.input)
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
