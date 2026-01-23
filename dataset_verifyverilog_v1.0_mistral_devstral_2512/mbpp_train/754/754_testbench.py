import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE/READ HELPERS
# ============================================================================

async def write_three_arrays(dut, l1, l2, l3):
    """Write values to three input arrays."""
    # Write l1
    for i in range(ARRAY_SIZE):
        val = l1[i] if i < len(l1) else 0
        port = getattr(dut, f'l1_{i}')
        port.value = clamp_to_width(val, DATA_WIDTH)
    
    # Write l2
    for i in range(ARRAY_SIZE):
        val = l2[i] if i < len(l2) else 0
        port = getattr(dut, f'l2_{i}')
        port.value = clamp_to_width(val, DATA_WIDTH)
    
    # Write l3
    for i in range(ARRAY_SIZE):
        val = l3[i] if i < len(l3) else 0
        port = getattr(dut, f'l3_{i}')
        port.value = clamp_to_width(val, DATA_WIDTH)

async def read_result_array(dut):
    """Read result array from DUT."""
    results = []
    result_count = 0
    
    # Read result_count
    if is_value_defined(dut.result_count.value):
        result_count = int(dut.result_count.value)
    
    # Read individual result ports
    for i in range(ARRAY_SIZE):
        port = getattr(dut, f'result_{i}')
        if is_value_defined(port.value):
            val = int(port.value)
            results.append(val)
        else:
            results.append(None)
    
    return results, result_count

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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
async def test_extract_index_list(dut):
    """Test the extract_index_list module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (l1, l2, l3, expected_list, description)
    test_cases = [
        (
            [1, 1, 3, 4, 5, 6, 7],
            [0, 1, 2, 3, 4, 5, 7],
            [0, 1, 2, 3, 4, 5, 7],
            [1, 7],
            "Test 1: matches at indices 1 and 6"
        ),
        (
            [1, 1, 3, 4, 5, 6, 7],
            [0, 1, 2, 3, 4, 6, 5],
            [0, 1, 2, 3, 4, 6, 7],
            [1, 6],
            "Test 2: matches at indices 1 and 5"
        ),
        (
            [1, 1, 3, 4, 6, 5, 6],
            [0, 1, 2, 3, 4, 5, 7],
            [0, 1, 2, 3, 4, 5, 7],
            [1, 5],
            "Test 3: matches at indices 1 and 5"
        ),
        (
            [1, 2, 3, 4, 6, 6, 6],
            [0, 1, 2, 3, 4, 5, 7],
            [0, 1, 2, 3, 4, 5, 7],
            [],
            "Test 4: no matches"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (l1, l2, l3, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  l1: {l1}")
        cocotb.log.info(f"  l2: {l2}")
        cocotb.log.info(f"  l3: {l3}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write input arrays
            await write_three_arrays(dut, l1, l2, l3)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            results, result_count = await read_result_array(dut)
            
            # Extract valid results (non-None values)
            valid_results = [r for r in results[:result_count] if r is not None]
            
            cocotb.log.info(f"  Result count: {result_count}")
            cocotb.log.info(f"  Results: {valid_results}")
            
            # Verify
            if result_count != len(expected):
                raise TestFailure(f"Count mismatch: expected {len(expected)}, got {result_count}")
            
            if valid_results != expected:
                raise TestFailure(f"Values mismatch: expected {expected}, got {valid_results}")
            
            cocotb.log.info(f"  Status: PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  Status: FAIL - {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"FINAL RESULTS: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
