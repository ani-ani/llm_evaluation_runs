import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 8
MAX_VAL = 16
MAX_SUM = N * MAX_VAL  # 128
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# ============================================================================
# HELPER FUNCTIONS
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
# ARRAY HELPERS
# ============================================================================

async def write_array(dut, values):
    """Write weights to DUT, handling array interface."""
    # Try 2D array first
    try:
        for i in range(N):
            val = values[i] if i < len(values) else 0
            dut.arr[i].value = clamp_to_width(val, DATA_WIDTH)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(N):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Missing port: {port_name}")

async def read_result(dut):
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined (X/Z)")
    return int(dut.result.value)

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_weight_query_solver(dut):
    """Test WeightQuerySolver module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (weights, expected, description)
    test_cases = [
        ([1, 4, 2, 2], 2, "Example 1: [1,4,2,2]"),
        ([1, 2, 4, 4, 4, 9], 2, "Example 2: [1,2,4,4,4,9]"),
        ([1], 1, "Single weight"),
        ([2, 2], 2, "Two identical"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 1, "All distinct"),
        ([5, 5, 5, 5, 5, 5, 5, 5], 8, "All same"),
        ([3, 3, 3, 7, 7, 7], 3, "Two groups of 3"),
        ([1, 2, 3, 4, 5, 6, 7, 16], 1, "Max value included"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (weights, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {description}")
        cocotb.log.info(f"Weights: {weights}")
        cocotb.log.info(f"Expected: {expected}")
        
        try:
            # Write inputs
            await write_array(dut, weights)
            
            # Start and wait
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\nResults: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")