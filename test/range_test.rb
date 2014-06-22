gem 'minitest', '~> 5.0'
require "minitest/autorun"

require "pgrange"

class RangeTest < Minitest::Test
  def test_include
    rng = PGRange.new(1, 3, '[)')
    assert rng.include?(1)
    assert rng.include?(2)
    refute rng.include?(3)
    refute rng.include?(0)
  end

  def test_wrong_bounds
    assert_raises ArgumentError do
      PGRange.new(1, 3, 'foo')
    end
  end

  def test_bad_value
    assert_raises ArgumentError do
      PGRange.new('a', 1)
    end
  end

  def test_to_s
    rng = PGRange.new(1, 3, '[)')
    assert_equal "[1,3)", rng.to_s
    assert_equal "[1,3)", rng.inspect
  end

  def test_empty
    rng = PGRange.new(1, 1, '[)')
    assert rng.empty?
    assert_equal nil, rng.upper
    assert_equal nil, rng.lower
    refute rng.lower_inc?
    refute rng.upper_inc?
    assert_equal "empty", rng.to_s

    rng = PGRange.new(1, 1, '[]')
    refute rng.empty?
  end

  def test_inf
    rng = PGRange.new(nil, 1, '[)')
    assert rng.lower_inf?
    refute rng.upper_inf?
    refute rng.lower_inc?
    refute rng.upper_inc?
    assert_equal "(,1)", rng.to_s

    assert_includes rng, 0
    assert_includes rng, -100
    refute_includes rng, 1
  end

  def test_eq
    assert_equal PGRange.new(1, 3), PGRange.new(1, 3)
    refute_equal PGRange.new(1, 4), PGRange.new(1, 3)
    refute_equal PGRange.new(1, 3, '[]'), PGRange.new(1, 3, '[)')

    assert_equal PGRange.new(nil, 3), PGRange.new(nil, 3)
    assert_equal PGRange.new(nil, nil), PGRange.new(nil, nil)
    refute_equal PGRange.new(nil, 4), PGRange.new(nil, 3)

    assert_equal PGRange.new(1, 1, '[]'), PGRange.new(1, 1, '[]')
  end
end
