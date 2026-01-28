import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Helpers ---
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    return min(max_val, v)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# --- Main Test ---
@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_nearest_tree_finder(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    dut.apple_r.value = 0
    dut.apple_c.value = 0
    dut.tree_map.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # --- Helper to calculate distance in Python ---
    def calc_dist(r1, c1, r2, c2):
        return (r1 - r2)**2 + (c1 - c2)**2

    # --- Test Scenarios ---
    # Scenario 1: Single tree at (0,0). Apple at (1,1). Dist = 2.
    # Tree map: bit 0 (row 0, col 0) set.
    dut.tree_map.value = 1  # 2^0
    dut.apple_r.value = 1
    dut.apple_c.value = 1
    dut.input_valid.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Check output on next cycle (latency 1)
    await RisingEdge(dut.clk)
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.result.value)
    expected = calc_dist(1, 1, 0, 0)
    
    if result != expected:
        raise TestFailure(f"Scenario 1 failed: Expected {expected}, got {result}")
    
    # Check updated tree map: should have bit 0 and bit (1*8 + 1) = 9 set
    # bit 0 = 1, bit 9 = 1 << 9 = 512. Total 513
    exp_map = 1 | (1 << 9)
    if int(dut.next_tree_map.value) != exp_map:
         raise TestFailure(f"Map Update 1 failed: Expected {exp_map}, got {int(dut.next_tree_map.value)}")

    # --- Scenario 2: Update map and query again ---
    # Use the output map as input for the next step
    dut.tree_map.value = int(dut.next_tree_map.value)
    # Apple at (0, 1). Closest is (0,0) dist 1, or (1,1) dist 2. Min = 1.
    dut.apple_r.value = 0
    dut.apple_c.value = 1
    dut.input_valid.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await RisingEdge(dut.clk)
    result = int(dut.result.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Scenario 2 failed: Expected {expected}, got {result}")

    # --- Scenario 3: No trees (Edge case handling) ---
    # Even though problem says at least one tree, hardware might handle empty.
    # We'll skip explicit empty map test as design assumes valid trees to save resources,
    # but we can verify behavior if map is empty (result might be garbage or max).
    # Instead, let's test a more complex map.
    # Map: (0,0), (2,2), (7,7)
    # Bits: 0, 2*8+2=18, 7*8+7=63
    dut.tree_map.value = (1 << 0) | (1 << 18) | (1 << 63)
    # Apple at (3,3). 
    # Dist to (0,0) = 18
    # Dist to (2,2) = 2
    # Dist to (7,7) = 32
    # Min = 2
    dut.apple_r.value = 3
    dut.apple_c.value = 3
    dut.input_valid.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await RisingEdge(dut.clk)
    result = int(dut.result.value)
    expected = 2
    if result != expected:
        raise TestFailure(f"Scenario 3 failed: Expected {expected}, got {result}")

    # --- Scenario 4: Maximum Distance (Corner to Corner) ---
    # Map: just (0,0)
    dut.tree_map.value = 1
    # Apple at (7,7)
    dut.apple_r.value = 7
    dut.apple_c.value = 7
    dut.input_valid.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await RisingEdge(dut.clk)
    result = int(dut.result.value)
    expected = calc_dist(7, 7, 0, 0) # 49 + 49 = 98
    if result != expected:
        raise TestFailure(f"Scenario 4 failed: Expected {expected}, got {result}")

    cocotb.log.info("All tests passed!")
