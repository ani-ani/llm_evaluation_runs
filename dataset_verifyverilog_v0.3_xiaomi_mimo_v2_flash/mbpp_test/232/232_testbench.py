import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
MAX_N = 5
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

# ============================================================================
# HELPER FUNCTIONS
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
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_array(dut, values):
    """Write values to individual array ports."""
    for i in range(ARRAY_SIZE):
        if i < len(values):
            val = clamp_to_width(values[i], DATA_WIDTH)
            getattr(dut, f'arr_{i}').value = val
        else:
            getattr(dut, f'arr_{i}').value = 0

async def read_results(dut, n):
    """Read the n largest results."""
    results = []
    result_ports = ['result_0', 'result_1', 'result_2', 'result_3', 'result_4']
    
    for i in range(min(n, MAX_N)):
        port = getattr(dut, result_ports[i])
        if is_value_defined(port.value):
            results.append(int(port.value))
        else:
            results.append(None)
    
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_larg_nnum(dut):
    """Test finding the n largest numbers in a list."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_list, n, expected_set, description)
    test_cases = [
        ([10, 20, 50, 70, 90, 20, 50, 40, 60, 80, 100], 2, {100, 90}, "n=2, top 2 values"),
        ([10, 20, 50, 70, 90, 20, 50, 40, 60, 80, 100], 5, {100, 90, 80, 70, 60}, "n=5, top 5 values"),
        ([10, 20, 50, 70, 90, 20, 50, 40, 60, 80, 100], 3, {100, 90, 80}, "n=3, top 3 values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, n, expected_set, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"Input: {input_list}, n={n}")
        cocotb.log.info(f"Expected set: {expected_set}")
        
        try:
            # Write input values to first 8 elements (use first 8 of input list)
            # The problem says "list" but we adapt to fixed-size array
            input_array = input_list[:8]
            await write_array(dut, input_array)
            
            # Set n value
            dut.n.value = n
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            results = await read_results(dut, n)
            
            # Validate results
            if None in results:
                raise TestFailure(f"Some result values are undefined: {results}")
            
            result_set = set(results)
            
            cocotb.log.info(f"Actual results: {results}")
            cocotb.log.info(f"Actual set: {result_set}")
            
            # Check if result set matches expected
            if result_set == expected_set:
                cocotb.log.info(f"Test {i+1} PASS: Result set matches expected")
                passed += 1
            else:
                raise TestFailure(f"Result set {result_set} does not match expected {expected_set}")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")