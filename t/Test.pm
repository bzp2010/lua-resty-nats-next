package t::Test;

use Test::Nginx::Socket::Lua::Stream -Base;
use Cwd qw(cwd);

no_root_location();

add_block_preprocessor(sub {
  my ($block) = @_;

  my $pwd = cwd();
  my $http_config = $block->http_config // '';

  $http_config .= <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;;";
_EOC_

  $block->set_value("http_config", $http_config);
})
