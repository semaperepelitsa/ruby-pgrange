class PGRange
  BOUNDS = {
    '[]' => [true, true],
    '[)' => [true, false],
    '(]' => [false, true],
    '()' => [false, false]
  }

  def initialize(lower, upper, bounds)
    @lower_inc, @upper_inc = BOUNDS.fetch(bounds) do
      values = BOUNDS.keys.map(&:inspect).join(', ')
      raise ArgumentError, "bounds must be one of #{values}"
    end

    @lower_inf = lower.nil? and @lower_inc = false
    @upper_inf = upper.nil? and @upper_inc = false

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

  # Range compatibility
  alias_method :begin, :lower
  alias_method :end, :upper
end
