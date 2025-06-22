use t::Test 'no_plan';

repeat_each(5);

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

=== TEST 1: basic (per message)
--- config
  location /t {
    content_by_lua_block {
      local p = require("resty.nats.protocols.parser")
      local parser = p.new(function(type, msg)
        if type ~= p.MESSAGE_TYPE.PING and type ~= p.MESSAGE_TYPE.OK and not msg then
          ngx.say("EXCEPTION: ", type, " payload: nil")
          return
        end
        ngx.say("RECEIVED: ", type, " payload: ", (msg and msg.payload or "nil"))
        if type == p.MESSAGE_TYPE.HMSG then
          local resp = ""
          local headers = {}
          for k, v in pairs(msg.headers) do table.insert(headers, {k = k, v = v}) end
          table.sort(headers, function(a, b) return a.k < b.k end)
          for _, v in ipairs(headers) do
            resp = resp .. v.k .. ": " .. v.v .. ";"
          end
          ngx.say("RECEIVED HEADERS: ", resp)
        end
      end)

      local lines = {
        "PING\r\n",
        "MSG foo.bar 1 10\r\nhelloworld\r\n",
        "MSG foo.bar 10 10\r\nhelloworld\r\n",
        "MSG foo.bar 100 10\r\nhelloworld\r\n",
        "HMSG foo.bar 1 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\n",
        "HMSG foo.bar 1 48 59\r\nNATS/1.0\r\nFoodGroup: vegetable\r\nFood: Carrot\r\n\r\nHello World\r\n",
        "-ERR 'TestErr1'\r\n",
        "+OK\r\n",
        'INFO {"test1":"test1","test2":"test2"}\r\n',
      }

      for _, line in ipairs(lines) do
        local err = parser:parse(line)
        if err then
          ngx.say("EXCEPTION: ", err)
          return
        end
      end
    }
  }
--- response_body
RECEIVED: PING payload: nil
RECEIVED: MSG payload: helloworld
RECEIVED: MSG payload: helloworld
RECEIVED: MSG payload: helloworld
RECEIVED: HMSG payload: Hello World
RECEIVED HEADERS: FoodGroup: vegetable;
RECEIVED: HMSG payload: Hello World
RECEIVED HEADERS: Food: Carrot;FoodGroup: vegetable;
RECEIVED: -ERR payload: TestErr1
RECEIVED: +OK payload: nil



=== TEST 2: random segments
--- config
  location /t {
    content_by_lua_block {
      local p = require("resty.nats.protocols.parser")
      local parser = p.new(function(type, msg)
        if type ~= p.MESSAGE_TYPE.PING and type ~= p.MESSAGE_TYPE.OK and not msg then
          ngx.say("EXCEPTION: ", type, " payload: nil")
          return
        end
        ngx.say("RECEIVED: ", type, " payload: ", (msg and msg.payload or "nil"), " sid: ", (msg and msg.sid or "nil"))
        if type == p.MESSAGE_TYPE.HMSG then
          local resp = ""
          local headers = {}
          for k, v in pairs(msg.headers) do table.insert(headers, {k = k, v = v}) end
          table.sort(headers, function(a, b) return a.k < b.k end)
          for _, v in ipairs(headers) do
            resp = resp .. v.k .. ": " .. v.v .. ";"
          end
          ngx.say("RECEIVED HEADERS: ", resp)
        end
      end)

      local lines = "PING\r\nMSG foo.bar 1 10\r\nhelloworld\r\nMSG foo.bar 10 10\r\nhelloworld\r\nPING\r\nMSG foo.bar 100 10\r\nhelloworld\r\nPING\r\nMSG foo.bar 1 10\r\nhelloworld\r\nHMSG foo.bar 1 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\nMSG foo.bar 10 10\r\nhelloworld\r\n-ERR 'TestErr1'\r\nHMSG foo.bar 1 48 59\r\nNATS/1.0\r\nFoodGroup: vegetable\r\nFood: Carrot\r\n\r\nHello World\r\nMSG foo.bar 100 10\r\nhelloworld\r\nPING\r\nMSG foo.bar 1 10\r\nhelloworld\r\nHMSG foo.bar 1 48 59\r\nNATS/1.0\r\nFoodGroup: vegetable\r\nFood: Carrot\r\n\r\nHello World\r\nMSG foo.bar 10 10\r\nhelloworld\r\n-ERR 'TestErr2'\r\nMSG foo.bar 100 10\r\nhelloworld\r\nMSG foo.bar 1 10\r\nhelloworld\r\nPING\r\nHMSG foo.bar 1 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\nPING\r\nMSG foo.bar 10 10\r\nhelloworld\r\n+OK\r\nHMSG foo.bar 1 48 59\r\nNATS/1.0\r\nFoodGroup: vegetable\r\nFood: Carrot\r\n\r\nHello World\r\nMSG foo.bar 100 10\r\nhelloworld\r\n-ERR 'TestErr3'\r\nHMSG foo.bar 1 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\nMSG foo.bar 1 10\r\nhelloworld\r\nPING\r\nMSG foo.bar 10 10\r\nhelloworld\r\nMSG foo.bar 100 10\r\nhelloworld\r\nHMSG foo.bar 1 48 59\r\nNATS/1.0\r\nFoodGroup: vegetable\r\nFood: Carrot\r\n\r\nHello World\r\nMSG foo.bar 1 10\r\nhelloworld\r\nPING\r\n+OK\r\nMSG foo.bar 10 10\r\nhelloworld\r\nMSG foo.bar 100 10\r\nhelloworld\r\nMSG foo.bar 1 10\r\nhelloworld\r\nPING\r\nMSG foo.bar 10 10\r\nhelloworld\r\nMSG foo.bar 100 10\r\nhelloworld\r\nHMSG foo.bar 1 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\nPING\r\n+OK\r\nMSG foo.bar 1 10\r\nhelloworld\r\nMSG foo.bar 10 10\r\nhelloworld\r\nHMSG foo.bar 1 48 59\r\nNATS/1.0\r\nFoodGroup: vegetable\r\nFood: Carrot\r\n\r\nHello World\r\n-ERR 'TestErr4'\r\nMSG foo.bar 100 10\r\nhelloworld\r\nMSG foo.bar 1 10\r\nhelloworld\r\n+OK\r\nMSG foo.bar 10 10\r\nhelloworld\r\nHMSG foo.bar 1 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\nMSG foo.bar 100 10\r\nhelloworld\r\nPING\r\n"

      local function split_random(s, n)
        math.randomseed(os.time())
        local l, t, p = #s, {}, {}
        for i = 1, n do
          t[i] = math.random(math.floor(i * l / (n + 1) - l / (2 * (n + 1))), math.floor(i * l / (n + 1) + l / (2 * (n + 1))))
        end
        table.sort(t)
        t[#t+1] = l
        local last = 1
        for i = 1, #t do
          p[i] = s:sub(last, t[i])
          last = t[i] + 1
        end
        return p
      end
      
      for _, line in ipairs(split_random(lines, 8)) do
        local err = parser:parse(line)
        if err then
          ngx.say("EXCEPTION: ", err)
          return
        end
      end
    }
  }
--- response_body
RECEIVED: PING payload: nil sid: nil
RECEIVED: MSG payload: helloworld sid: 1
RECEIVED: MSG payload: helloworld sid: 10
RECEIVED: PING payload: nil sid: nil
RECEIVED: MSG payload: helloworld sid: 100
RECEIVED: PING payload: nil sid: nil
RECEIVED: MSG payload: helloworld sid: 1
RECEIVED: HMSG payload: Hello World sid: 1
RECEIVED HEADERS: FoodGroup: vegetable;
RECEIVED: MSG payload: helloworld sid: 10
RECEIVED: -ERR payload: TestErr1 sid: nil
RECEIVED: HMSG payload: Hello World sid: 1
RECEIVED HEADERS: Food: Carrot;FoodGroup: vegetable;
RECEIVED: MSG payload: helloworld sid: 100
RECEIVED: PING payload: nil sid: nil
RECEIVED: MSG payload: helloworld sid: 1
RECEIVED: HMSG payload: Hello World sid: 1
RECEIVED HEADERS: Food: Carrot;FoodGroup: vegetable;
RECEIVED: MSG payload: helloworld sid: 10
RECEIVED: -ERR payload: TestErr2 sid: nil
RECEIVED: MSG payload: helloworld sid: 100
RECEIVED: MSG payload: helloworld sid: 1
RECEIVED: PING payload: nil sid: nil
RECEIVED: HMSG payload: Hello World sid: 1
RECEIVED HEADERS: FoodGroup: vegetable;
RECEIVED: PING payload: nil sid: nil
RECEIVED: MSG payload: helloworld sid: 10
RECEIVED: +OK payload: nil sid: nil
RECEIVED: HMSG payload: Hello World sid: 1
RECEIVED HEADERS: Food: Carrot;FoodGroup: vegetable;
RECEIVED: MSG payload: helloworld sid: 100
RECEIVED: -ERR payload: TestErr3 sid: nil
RECEIVED: HMSG payload: Hello World sid: 1
RECEIVED HEADERS: FoodGroup: vegetable;
RECEIVED: MSG payload: helloworld sid: 1
RECEIVED: PING payload: nil sid: nil
RECEIVED: MSG payload: helloworld sid: 10
RECEIVED: MSG payload: helloworld sid: 100
RECEIVED: HMSG payload: Hello World sid: 1
RECEIVED HEADERS: Food: Carrot;FoodGroup: vegetable;
RECEIVED: MSG payload: helloworld sid: 1
RECEIVED: PING payload: nil sid: nil
RECEIVED: +OK payload: nil sid: nil
RECEIVED: MSG payload: helloworld sid: 10
RECEIVED: MSG payload: helloworld sid: 100
RECEIVED: MSG payload: helloworld sid: 1
RECEIVED: PING payload: nil sid: nil
RECEIVED: MSG payload: helloworld sid: 10
RECEIVED: MSG payload: helloworld sid: 100
RECEIVED: HMSG payload: Hello World sid: 1
RECEIVED HEADERS: FoodGroup: vegetable;
RECEIVED: PING payload: nil sid: nil
RECEIVED: +OK payload: nil sid: nil
RECEIVED: MSG payload: helloworld sid: 1
RECEIVED: MSG payload: helloworld sid: 10
RECEIVED: HMSG payload: Hello World sid: 1
RECEIVED HEADERS: Food: Carrot;FoodGroup: vegetable;
RECEIVED: -ERR payload: TestErr4 sid: nil
RECEIVED: MSG payload: helloworld sid: 100
RECEIVED: MSG payload: helloworld sid: 1
RECEIVED: +OK payload: nil sid: nil
RECEIVED: MSG payload: helloworld sid: 10
RECEIVED: HMSG payload: Hello World sid: 1
RECEIVED HEADERS: FoodGroup: vegetable;
RECEIVED: MSG payload: helloworld sid: 100
RECEIVED: PING payload: nil sid: nil
