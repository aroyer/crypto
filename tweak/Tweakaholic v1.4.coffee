###########################################################
##      Tweakaholic Algorithm v1.4
##
##            >btcorbust<
##
## BTC: 1KvPi4XybwC6bmErQ53GDKLvrJrobK1PER
## LTC: LW8v6hocT7jGaXfWxwJrU4taeYBRH4V5Kr
##
##        btcorbust@gmail.com
###########################################################
##
## Mix and match your favourite indicators
## to achieve the best possible results!
##
## Supported indicators:
##  Ichimoku, Parabolic SAR, AROON, MACD,
##  RSI, Stochastic, MFI
##
## Instrument data used by the indicators
## is pre-filtered using Heikin-Ashi candles.
##
###########################################################
## Configure algorithm parameters here
###########################################################
class Init
  @init_context: (context) ->
    # main algorithm config params
    context.ha = new HeikinAshi(3)
    context.ichi_bull = new Ichimoku(8, 11, 11, 11, 10)
    context.ichi_bear = new Ichimoku(7, 10, 11, 11, 42)
    context.config_bull = new Config(
      0.05, -2.20, -0.19, 0.25, #lo/lc/so/sc
      -0.10, 0, #kumo_pad-below/above
      0, 0, #chikou_span-low/high
      0.025, 0.20, #sar-accel/max
      10, 20, #aroon-period/threshold
      10, 21, 8, -1, 1, #macd-fast/slow/sig/low/high
      20, 48, 52, #rsi-period/low/high
      14, 3, 3, 15, 19, 81, 85, #stoch-k_fast/k_slow/d_slow/low_lim/low/high/high_lim
      21, 20, 40, #mfi-period/low/high
      3, 3 #buy/sell lookback
    )
    context.config_bear = new Config(
      0.10, -0.25, -0.30, 2.35, #lo/lc/so/sc
      0, -0.2, #kumo_pad-below/above
      0, -1, #chikou_span-low/high
      0.025, 0.20, #sar-accel/max
      5, 25, #aroon-period/threshold
      14, 22, 9, 0, 1, #macd-fast/slow/sig/low/high
      20, 48, 52, #rsi-period/low/high
      14, 3, 3, 15, 19, 81, 85, #stoch-k_fast/k_slow/d_slow/low_lim/low/high/high_lim
      21, 20, 40, #mfi-period/low/high
      3, 3 #buy/sell lookback
    )
    context.bull_market_threshold = -0.30
    context.bear_market_threshold = 0
    context.market_short = 15
    context.market_long = 85

    # limit order configuration
    # use this to control execution of limit orders
    context.limit_order_enabled = false
    context.limit_sell_adjust = 0.02
    context.limit_buy_adjust = 0.02
    context.limit_max_retries = 10
    context.limit_timeout = 45

    # used to prevent trades when balances are too low
    # set this to match the fee of the exchange you are using
    context.fee_percent = 0.6
    context.min_asset_amt = 0.01

    # test mode is for backtesting only!
    # use with at least 10 BTC and $5000
    context.test_mode = false

    # enable/disable plot lines
    context.plot = false

    # enable/disable tick logging and frequency
    context.tick = false
    context.tick_freq = 1

    # DO NOT MODIFY!
    context.tick_cnt = 0
    context.init = true


###########################################################
## The Decision class is where you mix, match and combine
## the trading indicators to shape your own algorithm.
###########################################################
class Decision
  @decide: (instrument, context, config, price, ichi, sar, aroon, rsi, macd, stoch, mfi) ->
    #############################################
    ## SELL
    #############################################

    # mix/match/combine the indicators to generate sell signals
    ichi_sell_weak = ichi.tk_diff <= config.long_close
    ichi_sell_strong = ichi.tk_diff <= config.short_open and ichi.tenkan_max <= ichi.kumo_min and ichi.chikou_span <= config.chikou_span_low

    sar_sell_weak = _.last(price) <= _.last(sar)
    sar_sell_strong = sar_sell_weak and Functions.was_lt(sar, price, config.sell_lookback)

    aroon_sell_weak = (_.last(aroon.up) - _.last(aroon.down)) <= -config.aroon_threshold
    aroon_sell_strong = aroon_sell_weak and Functions.was_gt(aroon.up, aroon.down, config.sell_lookback)

    rsi_sell_weak = _.last(rsi) <= config.rsi_high
    rsi_sell_weak2 = Functions.was_gt(rsi, config.rsi_high, config.sell_lookback)
    rsi_sell_weak3 = _.last(rsi) <= config.rsi_low
    rsi_sell_strong = rsi_sell_weak and rsi_sell_weak2

    macd_sell_weak = _.last(macd.histogram) <= config.macd_low
    macd_sell_strong = macd_sell_weak and _.last(macd.macd) < _.last(macd.signal) and Functions.was_gt(macd.macd, macd.signal, config.sell_lookback)

    stoch_sell_weak = _.last(stoch.k) >= config.stoch_high
    stoch_sell_strong = stoch_sell_weak and _.last(stoch.k) < config.stoch_high_limit and Functions.was_gte(stoch.k, config.stoch_high_limit, config.sell_lookback)

    mfi_sell = _.last(mfi) > config.mfi_high

    # mix/match/combine the sell signals to determine bearish-ness
    bearish = false
    bearish |= ichi_sell_weak and (sar_sell_weak or rsi_sell_weak3 or macd_sell_weak)
    bearish |= ichi_sell_strong and aroon_sell_weak

    # if bearish, sell!
    if bearish
      Trade.sell(instrument, context)


    #############################################
    ## BUY
    #############################################

    # mix/match/combine the indicators to generate buy signals
    ichi_buy_weak = ichi.tk_diff >= config.short_close
    ichi_buy_strong = ichi.tk_diff >= config.long_open and ichi.tenkan_min >= ichi.kumo_max and ichi.chikou_span >= config.chikou_span_high

    sar_buy_weak = _.last(price) >= _.last(sar)
    sar_buy_strong = sar_buy_weak and Functions.was_gt(sar, price, config.buy_lookback)

    aroon_buy_weak = (_.last(aroon.up) - _.last(aroon.down)) >= config.aroon_threshold
    aroon_buy_strong = aroon_buy_weak and Functions.was_lt(aroon.up, aroon.down, config.buy_lookback)

    rsi_buy_weak = _.last(rsi) >= config.rsi_low
    rsi_buy_weak2 = Functions.was_lt(rsi, config.rsi_low, config.buy_lookback)
    rsi_buy_weak3 = _.last(rsi) >= config.rsi_high
    rsi_buy_strong = rsi_buy_weak and rsi_sell_weak2

    macd_buy_weak = _.last(macd.histogram) >= config.macd_high
    macd_buy_strong = macd_buy_weak and _.last(macd.macd) > _.last(macd.signal) and Functions.was_lt(macd.macd, macd.signal, config.buy_lookback)

    stoch_buy_weak = _.last(stoch.k) <= config.stoch_low
    stoch_buy_strong = stoch_buy_weak and _.last(stoch.k) > config.stoch_low_limit and Functions.was_lte(stoch.k, config.stoch_low_limit, config.buy_lookback)


    # mix/match/combine the buy signals to determine bullish-ness
    bullish = false
    bullish |= ichi_buy_weak and (sar_buy_weak or rsi_buy_weak3)
    bullish |= ichi_buy_strong and (sar_buy_weak or rsi_buy_weak3) and aroon_buy_weak

    # if bullish, buy!
    if bullish
      Trade.buy(instrument, context)


###########################################################
## You can fiddle with buy sell conditions
## in the Trade class as you please...
###########################################################
class Trade
  @buy: (ins, context) ->
    if context.test_mode
      buy(ins, context.min_asset_amt)
    else if @can_buy(ins, context.min_asset_amt, context.fee_percent)
      if context.limit_order_enabled
        @lim_buy(ins, context)
      else
        buy(ins)

  @sell: (ins, context) ->
    if context.test_mode
      sell(ins, context.min_asset_amt)
    else if @can_sell(ins, context.min_asset_amt)
      if context.limit_order_enabled
        @lim_sell(ins, context)
      else
        sell(ins)

  @can_buy: (ins, min_btc, fee_percent) ->
    portfolio.positions[ins.curr()].amount >= ((ins.price * min_btc) * (1 + fee_percent / 100))

  @can_sell: (ins, min_btc) ->
    portfolio.positions[ins.asset()].amount >= min_btc

  @lim_buy: (ins, context) ->
    # set price low so it does not trade
    price = ins.price
    info "Base buy price: #{price}"
    # loop until order succeeds or max retries reached
    x = 0
    while x < context.limit_max_retries
      x++
      # adjust price up (rounded to 2 decimal places)
      price = (Math.round((price * (1 + context.limit_buy_adjust / 100)) * 100)) / 100
      info "* ##{x} -> adjusted buy price: #{price}"
      # submit order with adjusted price
      order = buy(ins, null, price, context.limit_timeout)
      # if order succeeded end loop early and return order
      if order
        return order

  @lim_sell: (ins, context) ->
    # set price high so it does not trade
    price = ins.price
    warn "Base sell price: #{price}"
    # loop until order succeeds or max retries reached
    x = 0
    while x < context.limit_max_retries
      x++
      # adjust price down (rounded to 2 decimal places)
      price = (Math.round((price * (1 - context.limit_sell_adjust / 100)) * 100)) / 100
      warn "* ##{x} -> adjusted sell price: #{price}"
      # submit order with adjusted price
      order = sell(ins, null, price, context.limit_timeout)
      # if order succeeded end loop early and return order
      if order
        return order


###################################################################################################
##
## Thar be dragons here! Modify the code below at your own risk!
## (jump to the bottom to change what is plotted when enabled)
##
###################################################################################################
class Config
  constructor: (@long_open, @long_close, @short_open, @short_close, @kumo_pad_below, @kumo_pad_above, @chikou_span_low, @chikou_span_high, @sar_accel, @sar_max, @aroon_period, @aroon_threshold, @macd_fast_period, @macd_slow_period, @macd_signal_period, @macd_low, @macd_high, @rsi_period, @rsi_low, @rsi_high, @stoch_k_fast, @stoch_k_slow, @stoch_d_slow, @stoch_low_limit, @stoch_low, @stoch_high, @stoch_high_limit, @mfi_period, @mfi_low, @mfi_high, @buy_lookback, @sell_lookback) ->


class Ichimoku
  constructor: (@tenkan_n, @kijun_n, @senkou_a_n, @senkou_b_n, @chikou_n) ->
    @price = 0.0
    @tenkan = 0.0
    @kijun = 0.0
    @senkou_a = []
    @senkou_b = []
    @chikou = []

  # get current ichimoku state
  current: ->
    c =
      price: @price
      tenkan: @tenkan
      kijun: @kijun
      senkou_a: @senkou_a[0]
      senkou_b: @senkou_b[0]
      chikou_span: Functions.diff(@chikou[@chikou.length - 1], @chikou[0])
    return c

  # update with latest instrument price data
  put: (ins) ->
    # update last close price
    @price = ins.close[ins.close.length - 1]
    # update tenkan sen
    @tenkan = this._hla(ins, @tenkan_n)
    # update kijun sen
    @kijun = this._hla(ins, @kijun_n)
    # update senkou span a
    @senkou_a.push((@tenkan + @kijun) / 2)
    Functions.splice(@senkou_a, @senkou_a_n)
    # update senkou span b
    @senkou_b.push(this._hla(ins, @senkou_b_n * 2))
    Functions.splice(@senkou_b, @senkou_b_n)
    # update chikou span
    @chikou.push(ins.close[ins.close.length - 1])
    Functions.splice(@chikou, @chikou_n)

  # calc average of price extremes (high-low avg) over specified period
  _hla: (ins, n) ->
    hh = _.max(ins.high[-n..])
    ll = _.min(ins.low[-n..])
    return (hh + ll) / 2


class HeikinAshi
  constructor: (@ha_method = 3) ->
    @ins =
      open: []
      close: []
      high: []
      low: []
      volumes: []

  # update with latest instrument price data
  put: (ins) ->
    # push raw volume
    @ins.volumes.push(ins.volumes[ins.volumes.length - 1])

    # current raw candle (open/close/high/low)
    curr_open = ins.open[ins.open.length - 1]
    curr_close = ins.close[ins.close.length - 1]
    curr_high = ins.high[ins.high.length - 1]
    curr_low = ins.low[ins.low.length - 1]
    if @ha_method <= 0
      # HA Disabled!
      @ins.open.push(curr_open)
      @ins.close.push(curr_close)
      @ins.high.push(curr_high)
      @ins.low.push(curr_low)

    # There seem to be two main ways to calculate Heikin-Ashi candlesticks...
    if @ha_method == 1
      # HA Method 1 -  implemented in accordance with:
      #  - http://www.investopedia.com/terms/h/heikinashi.asp
      #  - http://www.forextraders.com/forex-indicators/heiken-ashi-indicator-explained.html
      if @ins.open.length == 0
        # initial candle
        @ins.open.push(curr_open)
        @ins.close.push(curr_close)
        @ins.high.push(curr_high)
        @ins.low.push(curr_low)
      else
        # every other candle
        prev_open = ins.open[ins.open.length - 2]
        prev_close = ins.close[ins.close.length - 2]
        @ins.open.push((prev_open + prev_close) / 2)
        @ins.close.push((curr_open + curr_close + curr_high + curr_low) / 4)
        @ins.high.push(_.max([curr_high, curr_open, curr_close]))
        @ins.low.push(_.min([curr_low, curr_open, curr_close]))

    if @ha_method == 2
      # HA Method 2 -  implemented in accordance with:
      #  - http://daytrading.about.com/od/indicators/a/HeikinAshi.htm
      #  - http://stockcharts.com/help/doku.php?id=chart_school:chart_analysis:heikin_ashi#calculation
      if @ins.open.length == 0
        # initial candle
        @ins.open.push((curr_open + curr_close) / 2)
        @ins.close.push((curr_open + curr_close + curr_high + curr_low) / 4)
        @ins.high.push(curr_high)
        @ins.low.push(curr_low)
      else
        # every other candle
        # previous ha candle open/close
        prev_open_ha = @ins.open[@ins.open.length - 1]
        prev_close_ha = @ins.close[@ins.close.length - 1]
        # calculate current ha candle
        curr_open_ha = (prev_open_ha + prev_close_ha) / 2
        curr_close_ha = (curr_open + curr_close + curr_high + curr_low) / 4
        @ins.open.push(curr_open_ha)
        @ins.close.push(curr_close_ha)
        @ins.high.push(_.max([curr_high, curr_open_ha, curr_close_ha]))
        @ins.low.push(_.min([curr_low, curr_open_ha, curr_close_ha]))

    if @ha_method == 3
      # HA Method 3 - similar to method 2 except open is based on
      # previous raw candle instead of previous HA candle.
      if @ins.open.length == 0
        # initial candle
        @ins.open.push(curr_open)
        @ins.close.push(curr_close)
        @ins.high.push(curr_high)
        @ins.low.push(curr_low)
      else
        # every other candle
        # previous raw candle open/close
        prev_open = ins.open[ins.open.length - 2]
        prev_close = ins.close[ins.close.length - 2]
        # calculate current ha candle
        curr_open_ha = (prev_open + prev_close) / 2
        curr_close_ha = (curr_open + curr_close + curr_high + curr_low) / 4
        @ins.open.push(curr_open_ha)
        @ins.close.push(curr_close_ha)
        @ins.high.push(_.max([curr_high, curr_open_ha, curr_close_ha]))
        @ins.low.push(_.min([curr_low, curr_open_ha, curr_close_ha]))

    if @ha_method == 4
      # HA Method 4 - similar to method 2 except open is based on
      # combination of previous raw candle and previous HA candle.
      if @ins.open.length == 0
        # initial candle
        @ins.open.push(curr_open)
        @ins.close.push(curr_close)
        @ins.high.push(curr_high)
        @ins.low.push(curr_low)
      else
        # every other candle
        # previous raw candle (close)
        prev_close = ins.close[ins.close.length - 2]
        # previous ha candle (open)
        prev_open_ha = @ins.open[@ins.open.length - 1]
        # calculate current ha candle
        curr_open_ha = (prev_open_ha + prev_close) / 2
        curr_close_ha = (curr_open + curr_close + curr_high + curr_low) / 4
        @ins.open.push(curr_open_ha)
        @ins.close.push(curr_close_ha)
        @ins.high.push(_.max([curr_high, curr_open_ha, curr_close_ha]))
        @ins.low.push(_.min([curr_low, curr_open_ha, curr_close_ha]))

    # restrict array lengths to reasonable max
    _max_length = 250
    Functions.splice(@ins.open, _max_length)
    Functions.splice(@ins.close, _max_length)
    Functions.splice(@ins.high, _max_length)
    Functions.splice(@ins.low, _max_length)
    Functions.splice(@ins.volumes, _max_length)


class Functions
  # percent difference between values
  @diff: (x, y) ->
    ((x - y) / ((x + y) / 2)) * 100

  # TA-Lib EMA
  @ema: (data, period, last = false) ->
    results = talib.EMA
      inReal: data
      startIdx: 0
      endIdx: data.length - 1
      optInTimePeriod: period
    if last
      _.last(results)
    else
      results

  # TA-Lib Parabolic SAR
  @sar: (high, low, accel, max, last = false) ->
    results = talib.SAR
      high: high
      low: low
      startIdx: 0
      endIdx: high.length - 1
      optInAcceleration: accel
      optInMaximum: max
    if last
      _.last(results)
    else
      results

  # TA-Lib AROON
  @aroon: (high, low, period, last = false) ->
    results = talib.AROON
      high: high
      low: low
      startIdx: 0
      endIdx: high.length - 1
      optInTimePeriod: period
    if last
      result =
        up: _.last(results.outAroonUp)
        down: _.last(results.outAroonDown)
    else
      result =
        up: results.outAroonUp
        down: results.outAroonDown
    result

  # TA-Lib MACD
  @macd: (data, fast_period, slow_period, signal_period, last = false) ->
    results = talib.MACD
      inReal: data
      startIdx: 0
      endIdx: data.length - 1
      optInFastPeriod: fast_period
      optInSlowPeriod: slow_period
      optInSignalPeriod: signal_period
    if last
      result =
        macd: _.last(results.outMACD)
        signal: _.last(results.outMACDSignal)
        histogram: _.last(results.outMACDHist)
    else
      result =
        macd: results.outMACD
        signal: results.outMACDSignal
        histogram: results.outMACDHist
    result

  # TA-LIB Stochastic
  @stoch: (high, low, close, k_period_fast, k_period_slow, d_period_slow, ma_type = 0, last = false) ->
    # MAType: 0=SMA, 1=EMA, 2=WMA, 3=DEMA, 4=TEMA, 5=TRIMA, 6=KAMA, 7=MAMA, 8=T3 (Default=SMA)
    results = talib.STOCH
      high: high
      low: low
      close: close
      startIdx: 0
      endIdx: close.length - 1
      optInFastK_Period: k_period_fast
      optInSlowK_Period: k_period_slow
      optInSlowK_MAType: ma_type
      optInSlowD_Period: d_period_slow
      optInSlowD_MAType: ma_type
    if last
      result =
        k: _.last(results.outSlowK)
        d: _.last(results.outSlowD)
    else
      result =
        k: results.outSlowK
        d: results.outSlowD
    result

  # TA-Lib RSI
  @rsi: (data, period, last = false) ->
    results = talib.RSI
      inReal: data
      startIdx: 0
      endIdx: data.length - 1
      optInTimePeriod: period
    if last
      _.last(results)
    else
      results

  # TA-Lib MFI
  @mfi: (high, low, close, volume, period, last = false) ->
    results = talib.MFI
      high: high
      low: low
      close: close
      volume: volume
      startIdx: 0
      endIdx: close.length - 1
      optInTimePeriod: period
    if last
      _.last(results)
    else
      results

  # populates the target array with instrument price data
  @populate: (target, ins) ->
    for i in [0..ins.close.length - 1]
      t =
        open: ins.open[..i]
        close: ins.close[..i]
        high: ins.high[..i]
        low: ins.low[..i]
        volumes: ins.volumes[..i]
      target.put(t)

  # restrict array length to specified max
  @splice: (arr, l) ->
    while arr.length > l
      arr.splice(0, 1)

  # were any of the data values greater than
  # the reference values for the last n periods
  @was_gt: (data, ref, n) ->
    @_was(data, ref, n, (x, y) -> y > x)

  # were any of the data values greater than or equal to
  # the reference values for the last n periods
  @was_gte: (data, ref, n) ->
    @_was(data, ref, n, (x, y) -> y >= x)

  # were any of the data values less than
  # the reference values for the last n periods
  @was_lt: (data, ref, n) ->
    @_was(data, ref, n, (x, y) -> y < x)

  # were any of the data values less than or equal to
  # the reference values for the last n periods
  @was_lte: (data, ref, n) ->
    @_was(data, ref, n, (x, y) -> y <= x)

  @_was: (data, ref, n, cb) ->
    if _.isArray(ref)
      result = false
      if ref.length and data.length and n > 0
        n = _.min([ref.length, data.length, n])
        for i in [1..n]
          if cb(ref[ref.length - i], data[data.length - i])
            result = true
            break
      result
    else
      result = data[-n..].filter (y) -> cb(ref, y)
      result.length


init: (context) ->
  Init.init_context(context)


handle: (context, data) ->
  # log tick
  if context.tick and context.tick_cnt % context.tick_freq == 0
    debug "tick ##{context.tick_cnt}"
  context.tick_cnt++

  # get instrument
  instrument = data.instruments[0]

  # handle instrument data
  if context.init
    # initialise heikin-ashi
    Functions.populate(context.ha, instrument)
    # initialise ichimoku (from heikin-ashi data)
    Functions.populate(context.ichi_bull, context.ha.ins)
    Functions.populate(context.ichi_bear, context.ha.ins)
    # initialisation complete
    context.init = false
  else
    # handle new instrument (via heikin-ashi)
    context.ha.put(instrument)
    context.ichi_bull.put(context.ha.ins)
    context.ichi_bear.put(context.ha.ins)

  # determine current market condition (bull/bear)
  short = Functions.ema(context.ha.ins.close, context.market_short, true)
  long = Functions.ema(context.ha.ins.close, context.market_long, true)
  mkt_diff = Functions.diff(short, long)
  is_bull = mkt_diff >= context.bull_market_threshold
  is_bear = mkt_diff <= context.bear_market_threshold

  if is_bull or is_bear
    # market config
    if is_bull
      # bull market
      config = context.config_bull
      c = context.ichi_bull.current()
    else if is_bear
      # bear market
      config = context.config_bear
      c = context.ichi_bear.current()

    # historic price values to be used with signals
    price = context.ha.ins.close

    # calc ichi indicators
    ichi =
      tk_diff: Functions.diff(c.tenkan, c.kijun)
      tenkan_min: _.min([c.tenkan, c.kijun])
      tenkan_max: _.max([c.tenkan, c.kijun])
      kumo_min: _.min([c.senkou_a, c.senkou_b]) * (1 - config.kumo_pad_below / 100)
      kumo_max: _.max([c.senkou_a, c.senkou_b]) * (1 + config.kumo_pad_above / 100)
    # copy in current ichi state
    for own key of c
      ichi[key] = c[key]

    # calc parabolic sar indicator
    sar = Functions.sar(context.ha.ins.high, context.ha.ins.low, config.sar_accel, config.sar_max)

    # calc aroon indicator
    aroon = Functions.aroon(context.ha.ins.high, context.ha.ins.low, config.aroon_period)

    # calc rsi indicator
    rsi = Functions.rsi(context.ha.ins.close, config.rsi_period)

    # calc macd indicator
    macd = Functions.macd(context.ha.ins.close, config.macd_fast_period, config.macd_slow_period, config.macd_signal_period)

    # calc stochastic indicator
    stoch = Functions.stoch(context.ha.ins.high, context.ha.ins.low, context.ha.ins.close, config.stoch_k_fast, config.stoch_k_slow, config.stoch_d_slow)

    # calc mfi indicator
    mfi = Functions.mfi(context.ha.ins.high, context.ha.ins.low, context.ha.ins.close, context.ha.ins.volumes, config.mfi_period)

    # log/plot data
    if context.plot
      plot
      # you can modify what is plotted here
        price: _.last(price)
        short: short
        long: long
        tenkan: ichi.tenkan
        kijun: ichi.kijun
        senkou_a: ichi.senkou_a
        senkou_b: ichi.senkou_b
        sar: _.last(sar)

    # decision time!
    Decision.decide(instrument, context, config, price, ichi, sar, aroon, rsi, macd, stoch, mfi)
