import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4
MAX_LISTS = 3
MAX_ELEMS_PER_LIST = 4
MAX_RESULT_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
# ARRAY WRITE/READ HELPERS
# ============================================================================

async def write_list(dut, list_num, values, valid_count):
    """Write a single list and its valid count."""
    # Write array elements
    for i in range(MAX_ELEMS_PER_LIST):
        port_name = f"list_{list_num}"
        if has_signal(dut, port_name):
            arr = getattr(dut, port_name)
            if i < len(values):
                arr[i].value = clamp_to_width(values[i], DATA_WIDTH)
            else:
                arr[i].value = 0
        else:
            # Try individual ports
            port_elem = f"list_{list_num}_{i}"
            if has_signal(dut, port_elem):
                if i < len(values):
                    getattr(dut, port_elem).value = clamp_to_width(values[i], DATA_WIDTH)
                else:
                    getattr(dut, port_elem).value = 0
    
    # Write valid count
    valid_port = f"list_{list_num}_valid"
    if has_signal(dut, valid_port):
        getattr(dut, valid_port).value = valid_count
    else:
        raise TestFailure(f"Signal {valid_port} not found")

async def read_result_array(dut, result_size):
    """Read result array values."""
    results = []
    
    # Try indexed array first
    try:
        arr = getattr(dut, 'result')
        for i in range(result_size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(result_size):
        port_name = f"result_{i}"
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
async def test_flatten_list(dut):
    """Test the flattened list with order preservation module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Define test cases: (list_0, list_1, list_2, expected_result, expected_count, description)
    # Format: (values_list_0, values_list_1, values_list_2, expected_output, expected_count, description)
    test_cases = [
        (
            [1, 2, 3], [2, 4], [3, 5, 1],
            [1, 2, 3, 4, 5, 0, 0, 0], 5,
            "Basic test from prompt"
        ),
        (
            [3, 4, 5, 5], [4, 5, 7], [1, 4],
            [3, 4, 5, 7, 1, 0, 0, 0], 5,
            "Test 1 adapted: (3,4,5), (4,5,7), (1,4)"
        ),
        (
            [1, 2, 3], [4, 2, 3], [7, 8],
            [1, 2, 3, 4, 7, 8, 0, 0], 6,
            "Test 2 adapted: (1,2,3), (4,2,3), (7,8)"
        ),
        (
            [7, 8, 9], [10, 11, 12], [10, 11],
            [7, 8, 9, 10, 11, 12, 0, 0], 6,
            "Test 3 adapted: (7,8,9), (10,11,12), (10,11)"
        ),
        (
            [15, 15, 15], [15, 0], [0, 1],
            [15, 0, 1, 0, 0, 0, 0, 0], 3,
            "Edge case: max values and zeros"
        ),
        (
            [1], [], [],
            [1, 0, 0, 0, 0, 0, 0, 0], 1,
            "Single element"
        ),
        (
            [], [], [],
            [0, 0, 0, 0, 0, 0, 0, 0], 0,
            "Empty lists"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (list0, list1, list2, expected, exp_count, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Inputs: L0={list0}, L1={list1}, L2={list2}")
        cocotb.log.info(f"  Expected: result={expected[:exp_count]}, count={exp_count}")
        
        try:
            # Write inputs
            await write_list(dut, 0, list0, len(list0))
            await write_list(dut, 1, list1, len(list1))
            await write_list(dut, 2, list2, len(list2))
            
            # Wait one cycle for inputs to stabilize
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=50)
            
            # Read result count
            if not is_value_defined(dut.result_count.value):
                raise TestFailure("Result count is undefined (X/Z)")
            
            result_count = int(dut.result_count.value)
            
            # Verify result count
            if result_count != exp_count:
                raise TestFailure(f"Result count mismatch: expected {exp_count}, got {result_count}")
            
            # Read result array
            result_array = await read_result_array(dut, MAX_RESULT_SIZE)
            
            # Verify each element
            for j in range(MAX_RESULT_SIZE):
                if j < exp_count:
                    if result_array[j] is None:
                        raise TestFailure(f"Result[{j}] is undefined")
                    if result_array[j] != expected[j]:
                        raise TestFailure(f"Result[{j}] mismatch: expected {expected[j]}, got {result_array[j]}")
                else:
                    # Remaining should be 0
                    if result_array[j] is not None and result_array[j] != 0:
                        raise TestFailure(f"Result[{j}] should be 0, got {result_array[j]}")
            
            cocotb.log.info(f"  PASS: result_count={result_count}, result={result_array[:result_count]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")