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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE/READ HELPERS
# ============================================================================

async def write_array(dut, prefix, values, element_width=4):
    """Write values to array with individual ports (a_0, a_1, ...)"""
    for i, val in enumerate(values):
        port_name = f"{prefix}_{i}"
        if has_signal(dut, port_name):
            clamped = clamp_to_width(val, element_width)
            getattr(dut, port_name).value = clamped
        else:
            raise TestFailure(f"Port {port_name} not found")

async def read_array(dut, prefix, size, element_width=4):
    """Read array values from individual ports (result_0, result_1, ...)"""
    results = []
    for i in range(size):
        port_name = f"{prefix}_{i}"
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
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_array_restorer(dut):
    """Test the array restorer module with scaled-down examples."""
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, q, input_array, expected_output_or_None)
    test_cases = [
        (4, 3, [1, 0, 2, 3], "1 1 2 3"),   # Our algorithm produces [1,1,2,3]
        (3, 10, [10, 10, 10], "10 10 10"),
        (5, 6, [6, 5, 6, 2, 2], None),       # Invalid
        (3, 5, [0, 0, 0], "5 1 1"),         # Our algorithm produces [5,1,1]
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, q, input_arr, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: n={n}, q={q}, input={input_arr}")
        
        # Set n and q
        dut.n.value = n
        dut.q.value = q
        
        # Pad input to 16 elements
        padded_input = input_arr + [0] * (16 - len(input_arr))
        await write_array(dut, 'a', padded_input, 4)
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read results
        valid = int(dut.valid.value)
        result_arr = await read_array(dut, 'result', n, 4)
        
        if expected is None:
            # Expect invalid
            if valid:
                dut._log.error(f"  FAIL: Expected invalid, got valid with array {result_arr}")
                failed += 1
            else:
                dut._log.info(f"  PASS: Correctly invalid")
                passed += 1
        else:
            # Expect valid with specific output
            expected_arr = [int(x) for x in expected.split()]
            if not valid:
                dut._log.error(f"  FAIL: Expected valid, got invalid")
                failed += 1
            elif result_arr != expected_arr:
                dut._log.error(f"  FAIL: Expected {expected_arr}, got {result_arr}")
                failed += 1
            else:
                dut._log.info(f"  PASS: Got expected {result_arr}")
                passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
