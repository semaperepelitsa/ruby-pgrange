gem 'minitest', '~> 5.0'
require "minitest/autorun"

class PGRange
  BOUNDS = {
    '[]' => [true, true],
    '[)' => [true, false],
    '(]' => [false, true],
    '()' => [false, false]
  }

  def initialize(lower, upper, bounds)
    @bounds = bounds
    @lower_inc, @upper_inc = BOUNDS.fetch(bounds) do
      values = BOUNDS.keys.map(&:inspect).join(', ')
      raise ArgumentError, "bounds must be one of #{values}"
    end

    # has no points
    @empty = lower == upper && !(@lower_inc && @upper_inc)

    if @empty
      @lower_inc = false
      @upper_inc = false
      @lower = nil
      @upper = nil
    else
      @lower = lower
      @upper = upper
    end
  end

  attr_reader :lower, :upper

  def lower_inc?
    @lower_inc
  end

  def upper_inc?
    @upper_inc
  end

  def empty?
    @empty
  end

  def include? obj
    lower = @lower_inc ? obj >= @lower : obj > @lower
    upper = @upper_inc ? obj <= @upper : obj < @upper
    lower && upper
  end

  def to_s
    return "empty" if @empty
    inner = "#{@lower.inspect},#{@upper.inspect}"
    outer = @bounds.dup
    outer.insert 1, inner
  end
  alias_method :inspect, :to_s

  # Range compatibility
  alias_method :begin, :lower
  alias_method :end, :upper
end

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
end
