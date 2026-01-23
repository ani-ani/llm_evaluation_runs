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
# REFERENCE IMPLEMENTATION (scaled to 4 tasks)
# ============================================================================

def compute_min_threshold(a_list, b_list):
    """Compute the minimal threshold for given a and b lists (length 4)."""
    n = 4
    # All partitions: 10 cases
    # Partition 0: all singletons
    min_scaled = 10**9
    def update(a_first, b_first):
        nonlocal min_scaled
        if b_first > 0:
            scaled = (a_first * 1000 + b_first - 1) // b_first
            if scaled < min_scaled:
                min_scaled = scaled
    # Partition 0
    sum_a = sum(a_list)
    sum_b = sum(b_list)
    update(sum_a, sum_b)
    # Partition 1: pair (0,1) singles 2,3
    if a_list[0] != a_list[1]:
        if a_list[0] > a_list[1]:
            first_a, first_b = a_list[0], b_list[0]
        else:
            first_a, first_b = a_list[1], b_list[1]
        sum_a = first_a + a_list[2] + a_list[3]
        sum_b = first_b + b_list[2] + b_list[3]
        update(sum_a, sum_b)
    # Partition 2: pair (0,2) singles 1,3
    if a_list[0] != a_list[2]:
        if a_list[0] > a_list[2]:
            first_a, first_b = a_list[0], b_list[0]
        else:
            first_a, first_b = a_list[2], b_list[2]
        sum_a = first_a + a_list[1] + a_list[3]
        sum_b = first_b + b_list[1] + b_list[3]
        update(sum_a, sum_b)
    # Partition 3: pair (0,3) singles 1,2
    if a_list[0] != a_list[3]:
        if a_list[0] > a_list[3]:
            first_a, first_b = a_list[0], b_list[0]
        else:
            first_a, first_b = a_list[3], b_list[3]
        sum_a = first_a + a_list[1] + a_list[2]
        sum_b = first_b + b_list[1] + b_list[2]
        update(sum_a, sum_b)
    # Partition 4: pair (1,2) singles 0,3
    if a_list[1] != a_list[2]:
        if a_list[1] > a_list[2]:
            first_a, first_b = a_list[1], b_list[1]
        else:
            first_a, first_b = a_list[2], b_list[2]
        sum_a = first_a + a_list[0] + a_list[3]
        sum_b = first_b + b_list[0] + b_list[3]
        update(sum_a, sum_b)
    # Partition 5: pair (1,3) singles 0,2
    if a_list[1] != a_list[3]:
        if a_list[1] > a_list[3]:
            first_a, first_b = a_list[1], b_list[1]
        else:
            first_a, first_b = a_list[3], b_list[3]
        sum_a = first_a + a_list[0] + a_list[2]
        sum_b = first_b + b_list[0] + b_list[2]
        update(sum_a, sum_b)
    # Partition 6: pair (2,3) singles 0,1
    if a_list[2] != a_list[3]:
        if a_list[2] > a_list[3]:
            first_a, first_b = a_list[2], b_list[2]
        else:
            first_a, first_b = a_list[3], b_list[3]
        sum_a = first_a + a_list[0] + a_list[1]
        sum_b = first_b + b_list[0] + b_list[1]
        update(sum_a, sum_b)
    # Partition 7: pairs (0,1) and (2,3)
    if a_list[0] != a_list[1] and a_list[2] != a_list[3]:
        if a_list[0] > a_list[1]:
            first_a01, first_b01 = a_list[0], b_list[0]
        else:
            first_a01, first_b01 = a_list[1], b_list[1]
        if a_list[2] > a_list[3]:
            first_a23, first_b23 = a_list[2], b_list[2]
        else:
            first_a23, first_b23 = a_list[3], b_list[3]
        sum_a = first_a01 + first_a23
        sum_b = first_b01 + first_b23
        update(sum_a, sum_b)
    # Partition 8: pairs (0,2) and (1,3)
    if a_list[0] != a_list[2] and a_list[1] != a_list[3]:
        if a_list[0] > a_list[2]:
            first_a02, first_b02 = a_list[0], b_list[0]
        else:
            first_a02, first_b02 = a_list[2], b_list[2]
        if a_list[1] > a_list[3]:
            first_a13, first_b13 = a_list[1], b_list[1]
        else:
            first_a13, first_b13 = a_list[3], b_list[3]
        sum_a = first_a02 + first_a13
        sum_b = first_b02 + first_b13
        update(sum_a, sum_b)
    # Partition 9: pairs (0,3) and (1,2)
    if a_list[0] != a_list[3] and a_list[1] != a_list[2]:
        if a_list[0] > a_list[3]:
            first_a03, first_b03 = a_list[0], b_list[0]
        else:
            first_a03, first_b03 = a_list[3], b_list[3]
        if a_list[1] > a_list[2]:
            first_a12, first_b12 = a_list[1], b_list[1]
        else:
            first_a12, first_b12 = a_list[2], b_list[2]
        sum_a = first_a03 + first_a12
        sum_b = first_b03 + first_b12
        update(sum_a, sum_b)
    return min_scaled

# ============================================================================
# TEST CASES
# ============================================================================

test_cases = [
    # (a_list, b_list, expected_scaled)
    ([1, 2, 3, 4], [1, 1, 1, 1], 2500),          # All singletons, avg = 2.5
    ([5, 3, 2, 1], [1, 1, 1, 1], 2667),          # One pair (5,3) + singles, avg ≈ 2.6667
    ([5, 4, 3, 2], [1, 1, 1, 1], 4000),          # Two pairs (5,4)+(3,2), avg = 4
    ([5, 5, 3, 2], [1, 1, 1, 1], 3750),          # Invalid pair (5,5), all singles gives 3.75
    ([8, 10, 9, 9], [1, 1, 1, 1], 9000),         # Scaled example 1
    ([8, 10, 9, 8], [1, 10, 5, 1], 1267),        # Two pairs (10,8)+(9,8), avg ≈ 1.2667
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_compute_threshold(dut):
    """Test the compute_threshold module."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a0.value = 0
    dut.a1.value = 0
    dut.a2.value = 0
    dut.a3.value = 0
    dut.b0.value = 0
    dut.b1.value = 0
    dut.b2.value = 0
    dut.b3.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test each case
    for i, (a_vals, b_vals, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i}: a={a_vals}, b={b_vals}, expected={expected}")
        
        # Set inputs
        dut.a0.value = a_vals[0]
        dut.a1.value = a_vals[1]
        dut.a2.value = a_vals[2]
        dut.a3.value = a_vals[3]
        dut.b0.value = b_vals[0]
        dut.b1.value = b_vals[1]
        dut.b2.value = b_vals[2]
        dut.b3.value = b_vals[3]
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 20:
                raise TestFailure(f"Timeout waiting for done on test {i}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z) on test {i}")
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {i}: expected {expected}, got {result}")
        else:
            dut._log.info(f"  PASS: result = {result}")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")