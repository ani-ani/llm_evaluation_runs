import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Fixed-point helpers

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Map string names to indices (0-7)
NAME_MAP = {
    'pink': 0, 'blue': 1, 'red': 2, 'orange': 3, 
    'yellow': 4, 'green': 5, 'indigo': 6, 'violet': 7
}

CLK_NS = 10
MAX_CYCLES = 1000

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_lemonade_trade(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases based on problem examples
    test_cases = [
        {
            "input": "3\nblue pink 1.0\nred pink 1.5\nblue red 1.0",
            "expected": 1.5
        },
        {
            "input": "2\nblue red 1.0\nred pink 1.5",
            "expected": 0.0
        },
        {
            "input": "4\norange pink 1.9\nyellow orange 1.9\ngreen yellow 1.9\nblue green 1.9",
            "expected": 10.0
        },
        {
            "input": "8\nred pink 1.9\norange red 1.9\nyellow orange 1.9\ngreen yellow 1.9\nindigo green 0.6\nviolet indigo 0.6\npurple violet 0.6\nblue purple 0.6",
            "expected": 1.688960160000000
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"\n--- Test Case {i+1} ---")
        try:
            # Parse input
            lines = tc["input"].strip().split('\n')
            N = int(lines[0])
            
            # Prepare arrays for HDL (max 8 trades, max 8 types)
            offers = [0] * 8
            wants = [0] * 8
            rates = [0] * 8
            
            for j in range(1, len(lines)):
                parts = lines[j].split()
                offers[j-1] = NAME_MAP[parts[0]]
                wants[j-1] = NAME_MAP[parts[1]]
                rates[j-1] = float_to_fixed(float(parts[2]), 8) # Q8.8
            
            # Initialize input signals
            for j in range(8):
                getattr(dut, f'trade_offer_{j}').value = offers[j]
                getattr(dut, f'trade_want_{j}').value = wants[j]
                getattr(dut, f'trade_rate_{j}').value = rates[j]
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Timeout waiting for done signal")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
                
            result_val = int(dut.result.value)
            
            # Compare
            # Expected is in liters, HDL returns integer liters (clamped to 10)
            # Need to handle floating point comparison for large numbers
            # Logic: if expected >= 10.0, result must be 10
            # else, result must be floor(expected) or ceil depending on error margin
            # Since we scale to 10.0 max, exact match is expected for cases < 10
            
            exp_liters = tc["expected"]
            if exp_liters >= 10.0 - 0.0001: # Allow tolerance for float comparison
                expected_int = 10
            else:
                expected_int = int(exp_liters)
                # Allow fractional tolerance? No, problem says integer output for liters clamped to 10
                # Wait, output is floating point. Verilog output is integer liters.
                # Constraint says output is integer in HDL spec.
                # If expected is 1.5, HDL should output 1 or 2?
                # Re-read spec: "result: 16-bit integer representing blue lemonade in liters. Scale Q8.8 value by dividing by 256..."
                # This implies integer liters. The test cases have floats.
                # Adjustment: The HDL returns fixed point or integer?
                # Spec says: "Output M with absolute precision 10^-6". 
                # The prompt simplified to "result: 16-bit integer". 
                # Let's assume the HDL returns integer liters (clamped to 10).
                # Check example 1: 1.5 -> 1 (or 2?)
                # Example 3: 10.0 -> 10.
                # Example 4: 1.6889 -> 1 (or 2?)
                # Actually, the prompt says: "result: 16-bit integer representing blue lemonade in liters. Scale Q8.8 value by dividing by 256 (shift right 8) and clamp to max 10 liters (10 * 256 = 2560)."
                # So result is integer liters. We should check if result is close to expected.
                
                # Allow +/- 1 liter error due to integer truncation in intermediate steps if not careful?
                # Or strictly round? Prompt implies division (shift), which is truncation.
                # Let's check if result is within 1.0 of expected.
                
                if abs(result_val - exp_liters) > 1.0 + 0.001:
                     raise TestFailure(f"Expected ~{exp_liters}, got {result_val}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result_val}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
