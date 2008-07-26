def chi2inv(x, k)
  Math::exp(- x/2) / 2 * (1..(k/2-1)).inject(1.0) { |r, i| r * x * i }
end

def chi2p( chi, df )
  m = chi / 2
  sum = term = Math.exp( -m )
  (1 .. df/2).each do |i|
    term *= m/i
    sum += term
  end
  [1.0, sum].min
end

10.times do 
x = rand * 3
k = (rand * 5).to_i

puts "#{chi2inv(x, k)} = #{chi2p(x, k)}"
end
