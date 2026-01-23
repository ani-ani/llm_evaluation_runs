import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_restaurant_expected(dut):
    """Test the restaurant expected occupancy module."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, g, t, capacities, expected_occupancy)
    # Expected occupancy computed as sum_occupancy / count_sequences
    test_cases = [
        # Sample Input 1: n=3, g=3, t=2, capacities [1,2,3]
        # Expected: 3.666666667
        (3, 3, 2, [1,2,3], 3.666666667),
        # Sample Input 2: n=4, g=11, t=4, capacities [10,10,10,10]
        # Note: We scale down g to 4 for feasibility, so we adjust expected value.
        # For g=4, t=4, n=4, capacities [10,10,10,10], we need to compute manually.
        # Since we scale down, we'll use a small case.
        (2, 2, 2, [5,5], 3.0),  # Example: n=2, g=2, t=2, capacities [5,5]
        (1, 1, 1, [5], 1.0),     # Simple case
        (4, 4, 1, [1,2,3,4], 2.5),  # One hour, uniform group size 1-4, expected group size 2.5
    ]
    
    passed = 0
    failed = 0
    
    for test_case in test_cases:
        n, g, t, capacities, expected_occupancy = test_case
        
        # Only test if parameters within limits
        if n > 4 or g > 4 or t > 4:
            cocotb.log.info(f"Skipping test with n={n}, g={g}, t={t} (exceeds limits)")
            continue
        
        cocotb.log.info(f"Testing: n={n}, g={g}, t={t}, capacities={capacities}")
        
        # Pad capacities to 4 values
        while len(capacities) < 4:
            capacities.append(0)
        
        # Set inputs
        dut.n.value = n
        dut.g.value = g
        dut.t.value = t
        dut.c0.value = capacities[0]
        dut.c1.value = capacities[1]
        dut.c2.value = capacities[2]
        dut.c3.value = capacities[3]
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read outputs
        sum_occ = safe_int(dut.sum_occupancy.value)
        count_seq = safe_int(dut.count_sequences.value)
        
        # Compute expected value from module outputs
        if count_seq == 0:
            raise TestFailure("count_sequences is zero")
        
        result = sum_occ / count_seq
        
        # Check with tolerance
        tolerance = 1e-6
        if abs(result - expected_occupancy) > tolerance:
            cocotb.log.error(f"  FAIL: Expected {expected_occupancy}, got {result} (sum={sum_occ}, count={count_seq})")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: Result {result} matches expected {expected_occupancy}")
            passed += 1
        
        # Wait a few cycles before next test
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")