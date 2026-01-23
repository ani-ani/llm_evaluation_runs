import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
from math import comb

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        if value >= -((1 << (bits-1))):
            return value + (1 << bits)
        else:
            return 0
    return min(max_val, value)

# Fixed-point conversions
def q8_8(f):
    return int(f * 256)

def q16_16(f):
    return int(f * 65536)

def from_q16_16(q):
    return q / 65536.0

# Python reference implementation
def compute_profit_n(x, p, n):
    """Compute expected profit for n bets"""
    if n == 0:
        return 0.0
    total = 0.0
    x_frac = x / 100.0
    for k in range(n + 1):
        prob = comb(n, k) * (p ** k) * ((1 - p) ** (n - k))
        net = 2 * k - n
        if net >= 0:
            profit = net
        else:
            profit = net + x_frac * (n - 2 * k)
        total += prob * profit
    return total

def max_expected_profit(x, p):
    """Find maximum over n=0..64"""
    max_val = 0.0
    for n in range(65):
        val = compute_profit_n(x, p, n)
        if val > max_val:
            max_val = val
    return max_val

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_casino_profit(dut):
    """Test casino profit calculator"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (x, p, expected_profit)
    test_cases = [
        (0.0, 49.9, 0.0),
        (50.0, 49.85, 7.10178453),
        (20.0, 45.0, 0.0),
        (20.0, 30.0, 0.0),
        (75.0, 48.0, 0.0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x_float, p_float, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: x={x_float}%, p={p_float}%")
        
        # Convert to Q8.8
        x_q = q8_8(x_float)
        p_q = q8_8(p_float)
        
        # Check signal widths
        if x_q > 65535 or p_q > 65535:
            raise TestFailure(f"Input value overflow")
        
        # Apply inputs
        dut.x.value = x_q
        dut.p.value = p_q
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        done_seen = False
        for cycle in range(2000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_seen = True
                break
        
        if not done_seen:
            dut._log.error(f"  FAIL: Timeout waiting for done")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.profit.value):
            dut._log.error(f"  FAIL: Profit is undefined (X/Z)")
            failed += 1
            continue
        
        result_q = int(dut.profit.value)
        result_float = from_q16_16(result_q)
        
        # Verify with tolerance
        error = abs(result_float - expected)
        if error > 0.001:
            dut._log.error(f"  FAIL: Expected {expected:.8f}, got {result_float:.8f}, error={error:.8f}")
            failed += 1
        else:
            dut._log.info(f"  PASS: {result_float:.8f} (error={error:.8f})")
            passed += 1
        
        # Small delay between tests
        for _ in range(5):
            await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")