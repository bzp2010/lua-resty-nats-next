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

=== TEST 1: simple client (connect)
--- config
  location /t {
    content_by_lua_block {
      local client = require("resty.nats.client")
      local cli, err = client.connect({
        host = "127.0.0.1",
        port = 4222,
      })
      if not cli then
        ngx.log(ngx.ERR, "failed to connect to NATS server: ", err)
        return
      end
      ngx.say("ok")
    }
  }
--- request
GET /t
--- response_body
ok



=== TEST 2: simple client (publish&subscribe)
--- config
  location /t {
    content_by_lua_block {
      local client = require("resty.nats.client")
      local cli, err = client.connect({
        host = "127.0.0.1",
        port = 4222,
      })
      if not cli then
        ngx.log(ngx.ERR, "failed to connect to NATS server: ", err)
        return
      end

      cli:subscribe("foo.bar", function(message)
        ngx.log(ngx.INFO, "Received message: ", message.payload)
        cli:close()
      end)

      local thread = ngx.thread.spawn(function()
        cli:start_loop()
      end)
      
      local ok, err = cli:publish({subject = "foo.bar", payload = "hello world"})
      if not ok then
        ngx.log(ngx.ERR, "failed to publish message: ", err)
        return
      end

      ngx.thread.wait(thread)
    }
  }
--- request
GET /t
--- error_log
Received message: hello world
--- no_error_log
[error]
--- timeout: 5
