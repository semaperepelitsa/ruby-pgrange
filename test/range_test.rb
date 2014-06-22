gem 'minitest', '~> 5.0'
require "minitest/autorun"

require "pgrange"

class RangeBasicTest < Minitest::Test
  def test_default
    rng = PGRange.new(1, 3)
    assert_equal 1, rng.lower
    assert_equal 3, rng.upper
    assert rng.lower_inc?
    refute rng.upper_inc?
    refute rng.empty?
    assert_equal "[1,3)", rng.to_s
  end

  def test_normalize
    rng = PGRange.new(0, 2, '(]')
    assert_equal 1, rng.lower
    assert_equal 3, rng.upper
    assert rng.lower_inc?
    refute rng.upper_inc?
    refute rng.empty?
    assert_equal "[1,3)", rng.to_s
  end

  def test_single
    rng = PGRange.new(1, 1, '[]')
    refute rng.empty?
    assert_equal "[1,2)", rng.to_s
  end

  def test_empty
    rng = PGRange.new(1, 1, '[)')
    assert rng.empty?
    assert_equal nil, rng.upper
    assert_equal nil, rng.lower
    refute rng.lower_inc?
    refute rng.upper_inc?
    assert_equal "empty", rng.to_s
  end

  def test_lower_inf
    rng = PGRange.new(nil, 1, '[)')

    assert_nil rng.lower
    assert_equal 1, rng.upper

    assert rng.lower_inf?
    refute rng.upper_inf?

    refute rng.lower_inc?
    refute rng.upper_inc?

    assert_equal "(,1)", rng.to_s
  end

  def test_upper_inf
    rng = PGRange.new(1, nil, '[]')

    assert_equal 1, rng.lower
    assert_nil rng.upper

    refute rng.lower_inf?
    assert rng.upper_inf?

    assert rng.lower_inc?
    refute rng.upper_inc?

    assert_equal "[1,)", rng.to_s
  end

  def test_inf
    rng = PGRange.new(nil, nil, '[]')

    assert_nil rng.lower
    assert_nil rng.upper

    assert rng.lower_inf?
    assert rng.upper_inf?

    refute rng.lower_inc?
    refute rng.upper_inc?

    assert_equal "(,)", rng.to_s
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

  def test_impossible
    assert_raises ArgumentError do
      PGRange.new(5, 1)
    end
  end
end

class RangeOperationsTest < Minitest::Test
  def test_include
    rng = PGRange.new(1, 3)
    assert rng.include?(1)
    assert rng.include?(2)
    refute rng.include?(3)
    refute rng.include?(0)
  end

  def test_include_upper_inf
    rng = PGRange.new(1, nil)
    assert rng.include?(1)
    assert rng.include?(100)
    refute rng.include?(0)
  end

  def test_include_lower_inf
    rng = PGRange.new(nil, 1)
    refute rng.include?(1)
    refute rng.include?(2)
    assert rng.include?(0)
    assert rng.include?(-100)
  end

  def test_include_inf
    rng = PGRange.new(nil, nil)
    assert rng.include?(-100)
    assert rng.include?(0)
    assert rng.include?(100)
  end

  def test_include_empty
    rng = PGRange.new(1, 1)
    refute rng.include?(1)
    refute rng.include?(0)
    refute rng.include?(2)
  end

  def test_bad_operation
    assert_raises TypeError do
      PGRange.new(1, 2) + "hello"
    end
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

  def test_union
    a = PGRange.new(5, 15)
    assert_equal PGRange.new(5, 20), a + PGRange.new(10, 20)
    assert_equal PGRange.new(5, 20), a + (10...20)


    assert_raises ArgumentError do
      a + PGRange.new(16, 20)
    end

    assert_raises ArgumentError do
      a + PGRange.new(15, 20)
    end
  end

  def test_intersection
    a = PGRange.new(5, 15)
    assert_equal PGRange.new(10, 15), a * PGRange.new(10, 20)

    assert_empty a * PGRange.new(15, 20)
    assert_empty a * PGRange.new(16, 20)

    assert_equal PGRange.new(15, 15, '[]'), PGRange.new(5, 15, '[]') * PGRange.new(15, 20)
  end
end
