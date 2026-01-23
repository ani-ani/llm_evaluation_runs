import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_OFFERS = 8
MAX_SECTIONS = 16
MAX_COLORS = 8

color_map = {
    "BLUE": 0,
    "RED": 1,
    "WHITE": 2,
    "ORANGE": 3,
    "GREEN": 4,
}

def parse_and_scale_offers(input_str):
    lines = input_str.strip().split('\n')
    n = int(lines[0])
    offers = []
    for i in range(1, n+1):
        parts = lines[i].split()
        color_str = parts[0]
        A = int(parts[1])
        B = int(parts[2])
        scaled_A = (A-1) * 16 // 10000
        scaled_B = (B-1) * 16 // 10000
        if scaled_A < 0:
            scaled_A = 0
        if scaled_B > 15:
            scaled_B = 15
        if scaled_A > scaled_B:
            scaled_B = scaled_A
        color_code = color_map.get(color_str, 0)
        offers.append((color_code, scaled_A, scaled_B))
    return offers

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'load_en'):
        dut.load_en.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_fence_painter(dut):
    if not (has_signal(dut, 'clk') and has_signal(dut, 'rst_n')):
        raise TestFailure("DUT missing required signals: clk, rst_n")
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_inputs = [
        "2\nBLUE 1 5000\nRED 5001 10000\n",
        "3\nBLUE 1 6000\nRED 2000 8000\nWHITE 7000 10000\n",
        "4\nBLUE 1 3000\nRED 2000 5000\nORANGE 4000 8000\nGREEN 7000 10000\n",
        "2\nBLUE 1 4000\nRED 4002 10000\n",
        "3\nBLUE 1 6000\nRED 4000 10000\nORANGE 3000 8000\n"
    ]
    expected_outputs = [
        "2",
        "3",
        "IMPOSSIBLE",
        "IMPOSSIBLE",
        "2"
    ]
    
    for idx, (input_str, expected_str) in enumerate(zip(test_inputs, expected_outputs)):
        dut._log.info(f"Test case {idx+1}")
        
        offers = parse_and_scale_offers(input_str)
        num_offers = len(offers)
        
        # Load offers
        for i, (color_code, start, end) in enumerate(offers):
            dut.load_en.value = 1
            dut.offer_index.value = i
            dut.offer_color.value = color_code
            dut.offer_start.value = start
            dut.offer_end.value = end
            await RisingEdge(dut.clk)
            dut.load_en.value = 0
        
        # Clear remaining slots
        for i in range(num_offers, MAX_OFFERS):
            dut.load_en.value = 1
            dut.offer_index.value = i
            dut.offer_color.value = 0
            dut.offer_start.value = 0
            dut.offer_end.value = 0
            await RisingEdge(dut.clk)
            dut.load_en.value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 5000
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done in test case {idx+1}")
        
        # Read result
        valid = int(dut.valid.value)
        min_count = int(dut.min_count.value)
        
        # Verify
        if expected_str == "IMPOSSIBLE":
            if valid != 0:
                raise TestFailure(f"Test {idx+1}: Expected IMPOSSIBLE, got valid=1 count={min_count}")
            else:
                dut._log.info(f"Test {idx+1}: PASS (IMPOSSIBLE)")
        else:
            expected_count = int(expected_str)
            if valid != 1:
                raise TestFailure(f"Test {idx+1}: Expected count {expected_count}, got valid=0")
            if min_count != expected_count:
                raise TestFailure(f"Test {idx+1}: Expected {expected_count}, got {min_count}")
            else:
                dut._log.info(f"Test {idx+1}: PASS (count={min_count})")
        
        # Reset for next test
        await reset_dut(dut)
