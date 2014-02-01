###########################################################
##      Tweakaholic Algorithm v1.3
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
      0.025, 0.20 #sar-accel/max
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
#    context.limit_order_enabled = false  *** Use setting in Stats & Orders module
#    context.limit_sell_adjust = 0.02  *** Use setting in Stats & Orders module
#    context.limit_buy_adjust = 0.02  *** Use setting in Stats & Orders module
#    context.limit_max_retries = 10  *** Use setting in Stats & Orders module
#    context.limit_timeout = 45  *** Use setting in Stats & Orders module

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
    # example mixing/matching of signals:
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
    # example mixing/matching of signals:
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
#      if context.limit_order_enabled
#        @lim_buy(ins, context)
#      else
#        buy(ins)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Stats & Orders module v0.5.9 by sportpilot
#
# buy() method - with optional (, amount) parameter
#
      Stats.buy context
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  @sell: (ins, context) ->
    if context.test_mode
      sell(ins, context.min_asset_amt)
    else if @can_sell(ins, context.min_asset_amt)
#      if context.limit_order_enabled
#        @lim_sell(ins, context)
#      else
#        sell(ins)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Stats & Orders module v0.5.9 by sportpilot
#
# sell() method - with optional (, amount) parameter
#
      Stats.sell context
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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


# Heikin-Ashi calculation based on:
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
        @ins.open.push(ins.open[ins.open.length - 1])
        @ins.close.push(ins.close[ins.close.length - 1])
        @ins.high.push(ins.high[ins.high.length - 1])
        @ins.low.push(ins.low[ins.low.length - 1])
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

class Tweak1_3
#init: (context) ->
#  Init.init_context(context)


  @handle: (context, data) ->
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

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Stats & Orders module v0.5.9 by sportpilot
#
#   BTC: 1561k5XqWFJSHP8apmvGt15ecWjw9ZLKGi
#
#   Description: This module provides Statistics reporting
#     and the ability to use Limit Orders, change the
#     Trade Timeout, set Reserves for USD &/or BTC
#     and more...
#
#   Ref: https://cryptotrader.org/topics/332486/stats-orders-module
#   Usage:
#
# Functions code block
#   Installation: Paste this block just BEFORE the
#     init: method
#
class Stats
  @context: (context) ->
  # Context for Stats
    context.stats = 'all'             # Display Stats? (all = every stats period , sell = only on sells, both = only on buy or sell, off = no Stats)
    context.stats_period = 120        # Display Stats only every n minutes when .stats = 'all' (for Stats on every tick, this # should match the period selected)
    context.trade_emails = false      # Send an Email when a trade is attempted and another when it completes or fails (Live only)
    context.trade_log_entries = true  # Display msg in the log when a trade is attempted and another when it completes or fails
    context.balances = true           # Display Balances?
    context.gain_loss = true          # Display Gain / Loss?
    context.win_loss = true           # Display Win / Loss & Trade Fees?
    context.prices = true             # Display Prices?
  #  context.triggers = false         # Display Trade triggers? *** Temporarily disabled
  #
  # Context for Orders
  #
    context.asset_reserve = 0         # Asset Reserve
    context.curr_reserve = 0          # Currency Reserve
    context.buy_timeout = null        # buy timeout (null = default 30 sec)
    context.sell_timeout = null       # sell timeout (null = default 30 sec)
    context.use_limit_orders = false  # Use Limit orders rather than Market orders?
    context.buy_limit_percent = 0     # % to increase buy price with Limit order (e.g. 0.1)
    context.sell_limit_percent = 0    # % to decrease sell price with Limit order (e.g. 0.1)
    context.trade_retries = 0         # Retry Limit orders n number of times before failing (0 = default Limit order behavior, no retries)
    context.trade_adj_pct = 0         # Adjust Limit order price by % with each retry (e.g. 0.1)
    context.price_rounding = null     # Round order price to n decimal digits (null = no rounding)
  #
  # Required variables
  #   Comment any defined in the Host strategy code. The values listed here will be
  #     overwritten if they are later redefined by other code.
  #
    context.pair = 'btc_usd'          # Asset / Currency pair
    context.min_trade_asset = 0.01    # Minimum asset trade size of exchange (e.g. MtGox btc = 0.01)
    context.fee_percent = 0.6         # Exchange trade fee
  #
  # DO NOT change anything below
  #
    context.next_stats = 0
    context.time = 0
    context.mins = 0
    context.trade_value = null
    context.cur_ins = null
    context.cur_data = null
    context.cur_portfolio = null
    context.currencies = []
    context.curr = null
    context.asset = null
    context.trader_asset = null
    context.trader_curr = null
    context.value_initial = 0
    context.price_initial = 0
    context.asset_initial = 0
    context.curr_initial = 0
    context.fees_paid = 0
    context.buy_value = null
    context.traded = false
    context.trade_open = false
    context.trade_type = null
    # Ichi/Scalp
    context.mode = null
    # Win & Losses
    context.Strat1_win_cnt = 0
    context.Strat1_win_value = 0
    context.Strat1_loss_cnt = 0
    context.Strat1_loss_value = 0
    context.Strat2_win_cnt = 0
    context.Strat2_win_value = 0
    context.Strat2_loss_cnt = 0
    context.Strat2_loss_value = 0
#
# Serialized Context
#
  @serialize: (context)->
    next_stats:context.next_stats
    cur_ins:context.cur_ins
    cur_data:context.cur_data
    cur_portfolio:context.cur_portfolio
    currencies:context.currencies
    curr:context.curr
    asset:context.asset
    trader_asset:context.trader_asset
    trader_curr:context.trader_curr
    value_initial:context.value_initial
    price_initial:context.price_initial
    asset_initial:context.asset_initial
    curr_initial:context.curr_initial
    fees_paid:context.fees_paid
    traded:context.traded
    trade_open:context.trade_open
    Strat1_win_cnt:context.Strat1_win_cnt
    Strat1_win_value:context.Strat1_win_value
    Strat1_loss_cnt:context.Strat1_loss_cnt
    Strat1_loss_value:context.Strat1_loss_value
    Strat2_win_cnt:context.Strat2_win_cnt
    Strat2_win_value:context.Strat2_win_value
    Strat2_loss_cnt:context.Strat2_loss_cnt
    Strat2_loss_value:context.Strat2_loss_value

  @handle: (context, data)->
    context.cur_ins = data[context.pair]
    context.cur_data = data
    context.cur_portfolio = portfolio
    if context.value_initial == 0
      Stats.initial(context)
    context.trader_asset = context.cur_portfolio.positions[context.asset].amount
    context.trader_curr = context.cur_portfolio.positions[context.curr].amount

  @initial: (context) ->
    context.currencies.push (context.pair.split "_")[0]
    context.currencies.push (context.pair.split "_")[1]
    context.asset = context.currencies[0]
    context.curr = context.currencies[1]
    context.trader_asset = context.cur_portfolio.positions[context.asset].amount
    context.trader_curr = context.cur_portfolio.positions[context.curr].amount

    if context.trader_asset > 0
      context.asset_initial = context.trader_asset
      context.buy_value = (context.trader_asset * context.cur_ins.price) + context.trader_curr
      context.trade_open = true
    else
      context.asset_initial = context.trader_curr / context.cur_ins.price
    context.curr_initial = context.trader_curr
    context.price_initial = context.cur_ins.price
    context.value_initial = (context.cur_ins.price * context.trader_asset) + context.curr_initial

#
# finalize: method
#
  @finalize: (context)->
    if _.contains(['all', 'both', 'sell'], context.stats)
      context.stats = 'all'
      context.next_stats = 0
      debug "~~~~~~~~~~~~~~~~~~~~~~"
      debug "~  Final Stats"
      Stats.report(context)
  @exec_stats: (context) ->
    if context.next_stats == 0 then context.next_stats = context.time
    if context.time >= context.next_stats
      context.next_stats += context.stats_period
      return true

  @report: (context) ->
    data = context.cur_data
    context.time = data.at / 60000
    context.trader_asset = context.cur_portfolio.positions[context.asset].amount
    context.trader_curr = context.cur_portfolio.positions[context.curr].amount
    if (context.stats == 'all' and Stats.exec_stats(context)) or (context.traded and (context.stats == 'both' or context.stats =='all')) or (context.traded and context.stats == 'sell' and context.trade_type == 'sell')

      balance = (context.cur_ins.price * context.trader_asset) + context.trader_curr
      price = context.cur_ins.price.toFixed(5)
      open = context.cur_ins.open[context.cur_ins.open.length - 1].toFixed(5)
      high = context.cur_ins.high[context.cur_ins.high.length - 1].toFixed(5)
      low = context.cur_ins.low[context.cur_ins.low.length - 1].toFixed(5)
      gain_loss = (balance - context.value_initial).toFixed(5)
      gain_loss_pct = ((balance - context.value_initial) / context.value_initial * 100).toFixed(1)
      BH_gain_loss = (balance - (context.cur_ins.price * context.asset_initial)).toFixed(5)
      trade_gain_loss = (balance - (context.buy_value)).toFixed(5)
      trade_gain_loss_pct = ((balance - context.buy_value) / context.buy_value * 100).toFixed(1)
      bal_asset = context.trader_asset.toFixed(5)
      bal_curr = context.trader_curr.toFixed(5)
      balance = balance.toFixed(5)

      if context.traded is false
        debug "~~~~~~~~~~~~~~~~~~~~~~"
      else
        debug "~"

      if context.balances
        debug "Balance (#{context.curr}): #{balance} | #{context.curr}: #{bal_curr} | #{context.asset}: #{bal_asset}"
      if context.gain_loss
        if context.trade_open or context.traded
          debug "[G/L] Session: #{gain_loss} (#{gain_loss_pct}%) | Trade: #{trade_gain_loss} (#{trade_gain_loss_pct}%) | B&H: #{BH_gain_loss}"
        else
          debug "[G/L] Session: #{gain_loss} (#{gain_loss_pct}%) | B&H: #{BH_gain_loss}"

      if context.win_loss
        if context.mode == null
          if _.contains(['sell_amt', 'buy_amt'], context.trade_type)
            debug "[W/L]: Disabled | Fees: #{context.fees_paid.toFixed(5)}"
          else
            debug "[W/L]: #{context.Strat1_win_cnt} / #{context.Strat1_loss_cnt} | #{context.Strat1_win_value.toFixed(5)} / #{context.Strat1_loss_value.toFixed(5)} | Fees: #{context.fees_paid.toFixed(5)}"
        else
          debug "[W/L] Ichi: #{context.Strat1_win_cnt} / #{context.Strat1_loss_cnt} | #{context.Strat1_win_value.toFixed(5)} / #{context.Strat1_loss_value.toFixed(5)} | Scalp: #{context.Strat2_win_cnt} / #{context.Strat2_loss_cnt} ~ $#{context.Strat2_win_value.toFixed(5)} / $#{context.Strat2_loss_value.toFixed(5)}"

      if context.prices
        debug "Price: #{price} | O: #{open} | H: #{high} | L: #{low}"
    context.traded = false
    context.trade_value = null

#    if context.triggers and context.mode == 'ichi'
#      if context.trader_asset > 0
#        warn "Long - Close: #{tk_diff.toFixed(3)} >= #{config.long_close} [&] #{c.tenkan.toFixed(3)} <= #{c.kijun.toFixed(3)} [&] (#{c.chikou.toFixed(3)} <= #{sar.toFixed(3)} [or] #{rsi.toFixed(3)} <= #{config.rsi_low} [or] #{macd.histogram.toFixed(3)} <= #{config.macd_short})"
#        warn "Short - Open: #{tk_diff.toFixed(3)} >= #{config.short_open} [&] #{c.tenkan.toFixed(3)} <= #{c.kijun.toFixed(3)} [&] #{tenkan_max.toFixed(3)} <= #{kumo_min.toFixed(3)} [&] #{c.chikou_span.toFixed(3)} <= 0 [&] #{aroon.up} - #{aroon.down} < -#{config.aroon_threshold}"
#      else
#        warn "Short - Close: #{tk_diff.toFixed(3)} >= #{config.short_close} [&] #{c.tenkan.toFixed(3)} >= #{c.kijun.toFixed(3)} [&] (#{c.chikou.toFixed(3)} >= #{sar.toFixed(3)} [or] #{rsi.toFixed(3)} >= #{config.rsi_low} [or] #{macd.histogram.toFixed(3)} >= #{config.macd_long})"
#        warn "Long - Open: #{tk_diff.toFixed(3)} >= #{config.long_open} [&] #{c.tenkan.toFixed(3)} >= #{c.kijun.toFixed(3)} [&] #{tenkan_min.toFixed(3)} >= #{kumo_max.toFixed(3)} [&] #{c.chikou_span.toFixed(3)} >= 0 [&] #{aroon.up} - #{aroon.down} >= #{config.aroon_threshold}"

  @win_loss: (context) ->
    context.trader_asset = context.cur_portfolio.positions[context.asset].amount
    context.trader_curr = context.cur_portfolio.positions[context.curr].amount
    balance = (context.cur_ins.price * context.trader_asset) + context.trader_curr
    context.fees_paid += context.trade_value - balance
    trade_net = balance - context.buy_value
    if context.mode == 'ichi' or context.mode == null
      if trade_net >= 0
        context.Strat1_win_cnt += 1
        context.Strat1_win_value += trade_net
      else
        context.Strat1_loss_cnt += 1
        context.Strat1_loss_value += trade_net
    else if context.mode =='scalp'
      if trade_net >= 0
        context.Strat2_win_cnt += 1
        context.Strat2_win_value += trade_net
      else
        context.Strat2_loss_cnt += 1
        context.Strat2_loss_value += trade_net

  @trade_msg: (context, msg) ->
    if context.trade_log_entries then debug msg
    if context.trade_emails then sendEmail msg

  @rnd_price: (price, digits) ->
    if digits?
      price = Math.round(price * Math.pow(10, digits)) / Math.pow(10, digits)
    else
      return price

  @place_sell_order: (context, amt) ->
    x = 0
    trade_result = null
    if context.use_limit_orders
      trade_price = Stats.rnd_price(context.cur_ins.price * (1 - context.sell_limit_percent / 100), context.price_rounding)    # use Limit Order
    else
      trade_price = null                                                              # use Market Order
    if amt?
      trade_amount = _.min([amt, context.trader_asset - context.asset_reserve])
    else
      trade_amount = context.trader_asset - context.asset_reserve
    if trade_amount >= context.min_trade_asset
      if _.contains(['all', 'both', 'sell'], context.stats)
        debug "~~~~~~~~~~~~"
      while (x <= context.trade_retries)
        Stats.trade_msg(context, "Attempting a SELL of #{trade_amount.toFixed(5)} #{context.asset} at #{if trade_price? then trade_price.toFixed(5) else trade_price} #{context.curr} with a timeout of #{context.sell_timeout} secs")
        trade_result = sell context.cur_ins, trade_amount, trade_price, context.sell_timeout
        if not trade_result? and context.use_limit_orders
          x++
          trade_price = Stats.rnd_price(trade_price * (1 - context.trade_adj_pct / 100), context.price_rounding)
        else
          return trade_result
      Stats.trade_msg(context, "SELL of #{trade_amount.toFixed(5)} #{context.asset} at #{if trade_price? then trade_price.toFixed(5) else trade_price} #{context.curr} FAILED - Order not completed")
    else
        Stats.trade_msg(context, "Can't attempt SELL of #{trade_amount.toFixed(5)} #{context.asset} - Exchange minimum trade (#{context.min_trade_asset} #{context.asset}) not met")
    return null

  @place_buy_order: (context, amt) ->
    x = 0
    trade_result = null
    order_price = Stats.rnd_price(context.cur_ins.price * (1 + context.buy_limit_percent / 100), context.price_rounding)
    if context.use_limit_orders
      trade_price = order_price                                                     # use Limit Order
    else
      trade_price = null                                                            # use Market Order
    if amt?
      trade_amount = _.min([amt * order_price, context.trader_curr - context.curr_reserve]) / order_price
    else
      trade_amount = (context.trader_curr - context.curr_reserve) / order_price
    if trade_amount >= context.min_trade_asset
      if _.contains(['all', 'both', 'sell'], context.stats)
        debug "~~~~~~~~~~~~"
      while (x <= context.trade_retries)
        Stats.trade_msg(context, "Attempting a BUY of #{(trade_amount * (1 - context.fee_percent / 100)).toFixed(5)} #{context.asset} at #{if trade_price? then trade_price.toFixed(5) else trade_price} #{context.curr} with a timeout of #{context.buy_timeout} secs")
        trade_result = buy context.cur_ins, trade_amount, trade_price, context.buy_timeout
        if not trade_result? and context.use_limit_orders
          x++
          trade_price = Stats.rnd_price(trade_price * (1 + context.trade_adj_pct / 100), context.price_rounding)
        else
          return trade_result
      Stats.trade_msg(context, "BUY of #{trade_amount.toFixed(5)} #{context.asset} at #{if trade_price? then trade_price.toFixed(5) else trade_price} #{context.curr} FAILED - Order not completed")
    else
        Stats.trade_msg(context, "Can't attempt BUY of #{trade_amount.toFixed(5)} #{context.asset} - Exchange minimum trade (#{context.min_trade_asset} #{context.asset}) not met")
    return null

  @sell: (context, amt = null) ->
    if context.trader_asset >= context.min_trade_asset
      if context.trader_asset - context.asset_reserve > 0
        trade_result = Stats.place_sell_order(context, amt)
        if trade_result?
          Stats.trade_msg(context, "SELL completed - #{trade_result.amount.toFixed(5)} #{context.asset} at #{trade_result.price.toFixed(5)} #{context.curr}")
          context.trade_value = trade_result.amount * trade_result.price
          context.trader_curr += context.trade_value
          context.trader_asset -= trade_result.amount
          Stats.win_loss(context)
          context.trade_open = false
          if amt? then context.trade_type = 'sell_amt' else context.trade_type = 'sell'
        context.traded = true

  @buy: (context, amt = null) ->
    if context.trader_curr >= ((context.cur_ins.price * context.min_trade_asset) * (1 + context.fee_percent / 100)) and context.trader_curr > 0.0001
      if context.trader_curr - context.curr_reserve > 0
        buy_value = (context.trader_asset * context.cur_ins.price) + context.trader_curr
        trade_result = Stats.place_buy_order(context, amt)
        if trade_result?
          Stats.trade_msg(context, "BUY completed - #{trade_result.amount.toFixed(5)} #{context.asset} at #{trade_result.price.toFixed(5)} #{context.curr}")
          context.buy_value = buy_value
          context.trade_value = trade_result.amount * trade_result.price
          context.fees_paid += buy_value - context.trade_value
          context.trader_curr -= context.trade_value
          context.trader_asset += trade_result.amount
          context.trade_open = true
          if amt? then context.trade_type = 'buy_amt' else context.trade_type = 'buy'
        context.traded = true

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Stats & Orders module v0.5.9 by sportpilot
#
# context: method
#
init: (context)->
  Stats.context(context)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  Init.init_context(context)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Stats & Orders module v0.5.9 by sportpilot
#
# serialize: method
#
serialize: (context)->
  Stats.serialize(context)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Stats & Orders module v0.5.9 by sportpilot
#
# handle: method
#
handle: (context, data)->
  Stats.handle(context, data)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  Tweak1_3.handle(context, data)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Stats & Orders module v0.5.9 by sportpilot
#
# Process Stats
#
#   Installation: Paste this block at the end of ALL
#     other code or just BEFORE the finalize: method
#     if it exists.
#
#   NOTE: Pay attention to the indentation of the code
#           line. It must be adjusted for your host code.
#
  Stats.report(context)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Stats & Orders module v0.5.9 by sportpilot
#
# finalize: method
#
#   Installation: Replace: -->   finalize: (context)->
#     with a copy of this block
#
finalize: (context)->
  Stats.finalize(context)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
