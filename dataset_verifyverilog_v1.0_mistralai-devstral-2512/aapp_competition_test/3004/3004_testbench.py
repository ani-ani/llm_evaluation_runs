import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Scaled test data: max 12 offers, 16 sections (0-15)
# We scale inputs to fit the hardware constraints
# Original range 1-10000 -> Scaled 0-15
# Scaling factor: 10000 / 16 = 625. We map ranges roughly.

def scale_range(start, end):
    # Simple linear scaling to 0-15
    s = (start - 1) // 625
    e = (end - 1) // 625
    return s, e

color_map = {
    "BLUE": 0, "RED": 1, "WHITE": 2, "ORANGE": 3, "GREEN": 2 # reuse color 2 for GREEN in example 3
}

# Test cases from problem description
test_cases = [
    {
        "offers": [("BLUE", 1, 5000), ("RED", 5001, 10000)],
        "expected": 2, "impossible": False
    },
    {
        "offers": [("BLUE", 1, 6000), ("RED", 2000, 8000), ("WHITE", 7000, 10000)],
        "expected": 3, "impossible": False
    },
    {
        "offers": [("BLUE", 1, 3000), ("RED", 2000, 5000), ("ORANGE", 4000, 8000), ("GREEN", 7000, 10000)],
        "expected": 0, "impossible": True
    },
    {
        "offers": [("BLUE", 1, 4000), ("RED", 4002, 10000)],
        "expected": 0, "impossible": True
    },
    {
        "offers": [("BLUE", 1, 6000), ("RED", 4000, 10000), ("ORANGE", 3000, 8000)],
        "expected": 2, "impossible": False
    }
]

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_fence_painter(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    passed = 0
    failed = 0

    for i, case in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        offers = case["offers"]
        num_offers = len(offers)
        
        # Check if we exceed hardware limit (12)
        if num_offers > 12:
            cocotb.log.info(f"Skipping case {i+1} (too many offers for scaled HW)")
            continue

        # Prepare inputs
        scaled_offers = []
        for color, start, end in offers:
            c = color_map.get(color, 0)
            s, e = scale_range(start, end)
            # Ensure valid range
            if s > e: e = s # Handle small ranges that might collapse
            scaled_offers.append((c, s, e))

        # Write to DUT
        # Use getattr for array elements as per rules
        for idx in range(12):
            if idx < num_offers:
                c, s, e = scaled_offers[idx]
                getattr(dut, f'offer_color_{idx}').value = clamp_to_width(c, 2)
                getattr(dut, f'offer_start_{idx}').value = clamp_to_width(s, 4)
                getattr(dut, f'offer_end_{idx}').value = clamp_to_width(e, 4)
            else:
                # Disable unused offers (ensure they don't interfere)
                getattr(dut, f'offer_start_{idx}').value = 0
                getattr(dut, f'offer_end_{idx}').value = 0

        dut.num_offers.value = clamp_to_width(num_offers, 4)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check results
        impossible = int(dut.impossible.value)
        min_offers = int(dut.min_offers.value)
        
        if case["impossible"]:
            if impossible == 1:
                cocotb.log.info(f"Case {i+1}: Correctly detected IMPOSSIBLE")
                passed += 1
            else:
                cocotb.log.error(f"Case {i+1}: Expected IMPOSSIBLE, got {min_offers}")
                failed += 1
        else:
            if impossible == 1:
                cocotb.log.error(f"Case {i+1}: Expected {case['expected']}, got IMPOSSIBLE")
                failed += 1
            elif min_offers == case["expected"]:
                cocotb.log.info(f"Case {i+1}: Correct result {min_offers}")
                passed += 1
            else:
                cocotb.log.error(f"Case {i+1}: Expected {case['expected']}, got {min_offers}")
                failed += 1

        # Reset for next case
        await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")