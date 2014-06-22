# A port of Postgres range type.
# Features:
# Both bound inclusion
# Infinite bounds
# Empty range
# Operations: union, intersection
class PGRange
  BOUNDS = {
    '[]' => [true, true],
    '[)' => [true, false],
    '(]' => [false, true],
    '()' => [false, false]
  }

  # Standard range:
  #   PGRange.new 1, 3 #=> [1,3)
  #
  # Range is normalized if discrete:
  #   PGRange.new 1, 3, '(]' #=> [2,4)
  #   PGRange.new 1, 3, '[]' #=> [1,4)
  #   PGRange.new 1, 3, '()' #=> [2,3)
  #
  # Non-discrete (Float) range:
  #   PGRange.new 1.1, 1.9, '()' #=> (1.1,1.9)
  #
  # Empty range:
  #   PGRange.new 1, 1 #=> empty
  #
  # Pass nil to have infinite bound:
  #   PGRange.new 1,   nil #=> [1,)
  #   PGRange.new nil, 1   #=> (,1)
  #   PGRange.new nil, nil #=> (,)
  #
  # Infinite bound is always exclusive.
  #   PGRange.new 1, nil, '[]' #=> [1,)
  #
  def initialize(lower, upper, bounds = '[)')
    @lower_inc, @upper_inc = BOUNDS.fetch(bounds) do
      values = BOUNDS.keys.map(&:inspect).join(', ')
      raise ArgumentError, "bounds must be one of #{values}"
    end

    @lower_inf = lower.nil? and @lower_inc = false
    @upper_inf = upper.nil? and @upper_inc = false

    unless @lower_inf || @upper_inf
      if (lower <=> upper) == nil
        raise ArgumentError, "bad value for range"
      end

      unless lower <= upper
        raise ArgumentError, "range lower bound must be less than or equal to range upper bound"
      end
    end

    # Time is no longer discrete and has deprecated #succ
    if !@lower_inc && lower.respond_to?(:succ) && !lower.kind_of?(Time)
      lower = lower.succ
      @lower_inc = true
    end

    if @upper_inc && upper.respond_to?(:succ) && !lower.kind_of?(Time)
      upper = upper.succ
      @upper_inc = false
    end

    # has no points
    @empty = lower == upper && !(@lower_inc && @upper_inc) && !(@lower_inf || @upper_inf)

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

  def lower_inc
    @lower_inc ? "[" : "("
  end

  def upper_inc?
    @upper_inc
  end

  def upper_inc
    @upper_inc ? "]" : ")"
  end

  # The range is empty when it includes no objects.
  # Example:
  #   PGRange.new(1, 1).empty? #=> true
  #   PGRange.new(1, 2).empty? #=> false
  def empty?
    @empty
  end

  def lower_inf?
    @lower_inf
  end

  def upper_inf?
    @upper_inf
  end

  # Does the range include this object?
  # Example:
  #   rng = PGRange.new(1, 3, '[)') # => [1,3)
  #   rng.cover?(0) #=> false
  #   rng.cover?(1) #=> true
  #   rng.cover?(2) #=> true
  #   rng.cover?(3) #=> false
  def cover? obj
    return false if @empty
    lower = @lower_inf || (@lower_inc ? obj >= @lower : obj > @lower)
    upper = @upper_inf || (@upper_inc ? obj <= @upper : obj < @upper)
    lower && upper
  end
  alias_method :===, :cover?

  # Find union with other range.
  def + other
    other = convert(other)

    return other if self.empty?
    return self if other.empty?

    if other.lower >= self.upper || (other.lower_inc? && self.upper_inc? && other.lower != self.upper)
      raise ArgumentError, "result of range union would not be contiguous"
    end

    case other.lower <=> self.lower
    when -1
      lrng = other
    when 1
      lrng = self
    when 0
      lrng = self.lower_inc? ? self : other
    end

    case other.upper <=> self.upper
    when 1
      urng = other
    when -1
      urng = self
    when 0
      urng = self.upper_inc? ? self : other
    end

    bounds = lrng.lower_inc + urng.upper_inc
    self.class.new(lrng.lower, urng.upper, bounds)
  end

  # Find intersection with other range.
  def * other
    other = convert(other)

    return self if self.empty?
    return other if other.empty?

    case other.lower <=> self.lower
    when -1
      lrng = self
    when 1
      lrng = other
    when 0
      lrng = self.lower_inc? ? other : self
    end

    case other.upper <=> self.upper
    when 1
      urng = self
    when -1
      urng = other
    when 0
      urng = self.upper_inc? ? other : self
    end

    bounds = lrng.lower_inc + urng.upper_inc
    lower = lrng.lower
    upper = urng.upper

    if lower > upper
      upper = lower
    end

    self.class.new(lower, upper, bounds)
  end

  def == other
    other.kind_of?(self.class) &&
    self.empty? == other.empty? &&
    self.lower == other.lower &&
    self.upper == other.upper &&
    self.lower_inc? == other.lower_inc? &&
    self.upper_inc? == other.upper_inc?
  end
  alias_method :eql?, :==

  def to_s
    return "empty" if @empty
    res = ""

    res << lower_inc
    res << @lower.inspect unless @lower_inf
    res << ","
    res << @upper.inspect unless @upper_inf
    res << upper_inc
  end
  alias_method :inspect, :to_s

  def to_pgrange
    self
  end

  # Range compatibility
  alias_method :begin, :lower
  alias_method :end, :upper

  def exclude_end?
    !upper_inc?
  end

  private

  def convert(other)
    if other.respond_to?(:to_pgrange)
      other.to_pgrange
    else
      raise TypeError, "no implicit conversion of #{other.class} into #{self.class}"
    end
  end
end

class Range
  def to_pgrange
    bounds = self.exclude_end? ? "[)" : "[]"
    PGRange.new(self.begin, self.end, bounds)
  end
end
