#!/usr/bin/env ruby

# Generate bird filters to update BGP community values
# see: https://dn42.net/howto/Bird
# original author: Mic92
# TODO
# - other bgp daemons, contribution are welcome

require 'open3'

def ping(host)
  print "Try to ping #{host}... (timeout 10s)"
  out, status = Open3.capture2e("ping", "-W10", "-c5", host)
  print "\r"
  if status != 0
    abort "ping failed with: #{status}\n#{out}"
  end
  last_line = out.lines.last
  fields = last_line.split(/\//)
  average = fields[5]

  return average.to_i
end

def latency_class(latency)
  case latency
  when 0..2.7
    1
  when 2.7..7.3
    2
  when 7.3..20
    3
  else
    Math.log(latency).round
  end
end

def speed_class(speed)
  case speed.to_f
  when 0 # invalid number
    abort "invalid mbit_speed: #{speed}"
  when 0.1..0.99
    21
  when 1..9.99
    22
  when 10..99.9
    23
  when 100..999.9
    24
  when 1000..9999
    25
  else
    20 + Math.log10((speed.to_f) * 100).round
  end
end

def crypto_class(crypto)
  case crypto
  when "unencrypted"
    31
  when "unsafe"
    32
  when "encrypted"
    33
  when "pfs"
    34
  else
    abort "unknown type #{crypto}"
  end
end

def main(args)
  if args.size < 3
    puts "USAGE: #{$0} host mbit_speed unencrypted|unsafe|encrypted|pfs"
    exit(1)
  end
  host, mbit_speed, crypto_type = args

  speed_value   = speed_class(mbit_speed)
  crypto_value  = crypto_class(crypto_type)
  latency = ping(host)
  latency_value = latency_class(latency)
  date = Time.now.strftime("%Y-%m-%d")

  puts "  # #{latency} ms, #{mbit_speed} mbit/s, #{crypto_type} tunnel (updated: #{date})"
  puts "  import where dn42_import_filter(#{latency_value},#{speed_value},#{crypto_value});"
  puts "  export where dn42_export_filter(#{latency_value},#{speed_value},#{crypto_value});"
end

main(ARGV)
