import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import math

# Helper functions
DATA_WIDTH = 16
FRAC_BITS = 16
SCALE = 1 << FRAC_BITS
MAX_N = 256  # Bounded iterations

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def float_to_fixed(f, frac=FRAC_BITS):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=FRAC_BITS):
    return v / (1 << frac)

# Python reference function
def compute_expected_profit(p_frac, x_frac, max_n=256):
    p = p_frac / SCALE
    x = x_frac / SCALE
    max_profit = 0.0
    # Precompute binomial probabilities for small k (<=8) to avoid overflow
    # For each n from 0 to max_n, calculate probability of k wins (k from 0 to n)
    for n in range(max_n + 1):
        total_expected = 0.0
        # Limit k to reasonable max (e.g., 8) since p<0.5, probabilities drop quickly
        for k in range(0, min(n, 8) + 1):
            # Binomial probability: C(n,k) * p^k * (1-p)^(n-k)
            # Approximate using logs or direct multiplication for small n
            import math
            log_prob = (math.comb(n, k) * 
                        (math.log(p) if p > 0 else -math.inf) * k + 
                        (math.log(1-p) if 1-p > 0 else -math.inf) * (n-k))
            # Avoid numerical issues; use direct for small n
            prob = math.comb(n, k) * (p ** k) * ((1 - p) ** (n - k))
            # Profit for k wins: 2*k - n (net winnings before rebate)
            profit_win = 2 * k - n
            expected_profit_win = profit_win
            if profit_win < 0:
                # Loss: rebate x% of loss
                loss = -profit_win
                expected_profit_win = -loss * (1 - x)  # Keep (1-x) of loss
            total_expected += prob * expected_profit_win
        if total_expected > max_profit:
            max_profit = total_expected
    return max_profit

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_casino(dut):
    # No clock, combinational design
    await Timer(10, units='ns')
    
    test_cases = [
        (49.9, 0.0, 0.0),      # p=49.9%, x=0 -> output 0.0
        (49.85, 50.0, 7.10178453),  # p=49.85%, x=50 -> output ~7.10178
    ]
    
    for i, (p_percent, x_percent, exp_val) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: p={p_percent}%, x={x_percent}%")
        
        p_frac = float_to_fixed(p_percent / 100.0)
        x_frac = float_to_fixed(x_percent / 100.0)
        
        # Assign inputs
        dut.p_fixed.value = clamp_to_width(p_frac, DATA_WIDTH)
        dut.x_fixed.value = clamp_to_width(x_frac, DATA_WIDTH)
        
        # Wait for propagation
        await Timer(100, units='ns')
        
        # Read output
        if hasattr(dut, 'expected_profit'):
            result = int(dut.expected_profit.value)
            result_float = fixed_to_float(result)
            
            if abs(result_float - exp_val) > 1e-3:
                raise TestFailure(f"Expected {exp_val:.6f}, got {result_float:.6f}")
        else:
            raise TestFailure("Output signal expected_profit not found")
        
        cocotb.log.info(f"Result: {result_float:.6f}")