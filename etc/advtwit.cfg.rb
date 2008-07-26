require 'pit'

begin
  opts = {}
  unless false #opts[:twit_user] and opts[:twit_pass] # FIXME
    credentials = Pit.get("advtwit", :require => {
      "twit_nick" => "twitter username",
      "twit_pass" => "twitter password",
      })

    opts[:twit_nick] ||= credentials["twit_nick"] || credentials["twit_user"]
    opts[:twit_pass] ||= credentials["twit_pass"]
  end

  opts[:keywords] = "nyaxt 上野氏 cagra nytr FPGA 未踏 ユース 物理 advtwit".split(' ')
  opts[:hotnicks] = "ryo_grid nyaxt koizuka tokoroten tgbt frsyuki beinteractive q61501331 ranha showyou yuyarin kana1 kzk_mover natsutan coji rch850 pi8027 Mai_iaM ina_ani Alembert takuma104 misky deq ha_ma ykzts kinaba rosylilly tnzk kajuntk 5um4 oxy syou6162".split(' ')

  opts[:dbfile] = "var/advtwit.db"

  $advtwit_opts = opts
end
