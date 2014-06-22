class PGRange
  BOUNDS = {
    '[]' => [true, true],
    '[)' => [true, false],
    '(]' => [false, true],
    '()' => [false, false]
  }

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

  def lower_inf?
    @lower_inf
  end

  def upper_inf?
    @upper_inf
  end

  def include? obj
    lower = @lower_inf || (@lower_inc ? obj >= @lower : obj > @lower)
    upper = @upper_inf || (@upper_inc ? obj <= @upper : obj < @upper)
    lower && upper
  end

  # union
  def + other
    other = convert(other)
    lrng = [self, other].min_by(&:lower)
    urng = [self, other].max_by(&:upper)

    bounds = ""
    bounds << (lrng.lower_inc? ? "[" : "(")
    bounds << (urng.upper_inc? ? "]" : ")")

    self.class.new(lrng.lower, urng.upper, bounds)
  end

  # intersection
  def * other
    other = convert(other)
    lrng = [self, other].max_by(&:lower)
    urng = [self, other].min_by(&:upper)

    bounds = ""
    bounds << (lrng.lower_inc? ? "[" : "(")
    bounds << (urng.upper_inc? ? "]" : ")")

    self.class.new(lrng.lower, urng.upper, bounds)
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

    res << (@lower_inc ? "[" : "(")
    res << @lower.inspect unless @lower_inf
    res << ","
    res << @upper.inspect unless @upper_inf
    res << (@upper_inc ? "]" : ")")
  end
  alias_method :inspect, :to_s

  def to_pgrange
    self
  end

  # Range compatibility
  alias_method :begin, :lower
  alias_method :end, :upper

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
