import math

def cents(x): return int(round(x*100))
def dollars(c): return c/100.0

def round_ending_99(cents_in):
    # force .99 psychological pricing
    d = dollars(cents_in)
    d = math.floor(d) + 0.99
    return cents(d)

def compute_price_cents(item):
    """
    Inputs (if present on item):
      - cost_cents or cost
      - shipping_cents (our cost)
      - map_cents (minimum advertised price)
      - competitors: [{price_cents|price, vendor}, ...]
      - baseline_cents (fallback baseline)
      - min_margin_pct (e.g. 0.20 -> 20%)
    Policy:
      price = min_competitor - $1
      floor at max(cost_total * (1+min_margin_pct), map_cents if set)
      never negative, round to .99
    """
    cost = item.get('cost_cents')
    if cost is None and 'cost' in item: cost = cents(float(item['cost']))
    if cost is None: cost = cents(5.00)  # conservative fallback

    ship = item.get('shipping_cents', 0)
    if ship is None and 'shipping' in item: ship = cents(float(item['shipping']))

    cost_total = cost + max(0, ship)

    # competitor minimum
    comp_prices = []
    for c in item.get('competitors', []):
        p = c.get('price_cents')
        if p is None and 'price' in c: 
            try: p = cents(float(c['price']))
            except: continue
        if isinstance(p, int) and p > 0: comp_prices.append(p)
    min_comp = min(comp_prices) if comp_prices else None

    # target: $1 cheaper than lowest competitor
    if min_comp:
        target = max(min_comp - cents(1.00), 0)
    else:
        # fallback to baseline or small markup over cost
        baseline = item.get('baseline_cents')
        if baseline is None and 'baseline' in item:
            try: baseline = cents(float(item['baseline']))
            except: baseline = None
        target = baseline if isinstance(baseline,int) and baseline>0 else int(cost_total * 1.25)

    # margin floor
    min_margin = item.get('min_margin_pct', 0.20)
    floor_price = int(round(cost_total * (1.0 + max(0.0, float(min_margin)))))

    # MAP floor
    map_cents = item.get('map_cents')
    if map_cents is None and 'map' in item:
        try: map_cents = cents(float(item['map']))
        except: map_cents = None
    if isinstance(map_cents,int) and map_cents>0:
        floor_price = max(floor_price, map_cents)

    final_cents = max(target, floor_price)
    # rounding to .99
    final_cents = round_ending_99(final_cents)
    return final_cents
