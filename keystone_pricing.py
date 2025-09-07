import math
import random

def dynamic_price(cost: float, demand_index: float, competitor_price: float) -> float:
    """
    Calculate fair dynamic price.
    - cost: baseline wholesale or estimated sourcing cost
    - demand_index: float 0–1 representing relative demand (0=low, 1=high)
    - competitor_price: average competitor price for same item
    """

    # Ensure inputs are valid
    cost = max(cost, 0.01)
    competitor_price = max(competitor_price, cost)

    # Margin factor: higher demand => higher margin
    margin = 0.10 + (0.25 * demand_index)  # 10%–35%

    # Base price calculation
    target_price = cost * (1 + margin)

    # Blend with competitor price to avoid under/over pricing
    final_price = (0.6 * target_price) + (0.4 * competitor_price)

    # Round to “psychological” retail number
    return round(final_price, 2)
