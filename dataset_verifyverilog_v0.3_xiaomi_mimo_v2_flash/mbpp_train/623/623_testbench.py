import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 32
EXP_WIDTH = 5
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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

def python_power(base, exponent):
    """Compute base^exponent in Python (for verification)."""
    if exponent == 0:
        return 1
    if exponent == 1:
        return base
    result = 1
    for _ in range(exponent):
        result *= base
    return result

# ============================================================================
# ARRAY WRITE/READ HELPERS
# ============================================================================

async def write_input_array(dut, values):
    """Write values to input array using individual ports."""
    for i in range(ARRAY_SIZE):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find input port: {port_name}")

async def read_output_array(dut):
    """Read values from output array using individual ports."""
    results = []
    for i in range(ARRAY_SIZE):
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

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'exponent'):
        dut.exponent.value = 0
    
    for _ in range(3):
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

async def start_computation(dut, exponent):
    """Pulse start signal and set exponent."""
    if has_signal(dut, 'exponent'):
        dut.exponent.value = clamp_to_width(exponent, EXP_WIDTH)
    else:
        raise TestFailure("Signal 'exponent' not found")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_power_calculator(dut):
    """Test element-wise power computation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Initial reset
    await reset_dut(dut)
    
    # Test cases: (input_array, exponent, expected_output_array, description)
    # Scaled down from original problem
    test_cases = [
        (
            [1, 2, 3, 4, 5, 6, 7, 8],
            2,
            [1, 4, 9, 16, 25, 36, 49, 64],
            "Square of 1-8"
        ),
        (
            [10, 20, 30, 0, 0, 0, 0, 0],
            3,
            [1000, 8000, 27000, 1, 1, 1, 1, 1],
            "Cube of 10,20,30 (padded)"
        ),
        (
            [12, 15, 0, 0, 0, 0, 0, 0],
            5,
            [248832, 759375, 1, 1, 1, 1, 1, 1],
            "5th power of 12,15 (padded)"
        ),
        (
            [1, 1, 1, 1, 1, 1, 1, 1],
            0,
            [1, 1, 1, 1, 1, 1, 1, 1],
            "All ones, exponent 0 (1^0=1)"
        ),
        (
            [2, 3, 4, 5, 6, 7, 8, 9],
            1,
            [2, 3, 4, 5, 6, 7, 8, 9],
            "Identity operation (exponent 1)"
        ),
        (
            [255, 2, 1, 0, 0, 0, 0, 0],
            2,
            [65025, 4, 1, 0, 1, 1, 1, 1],
            "Edge cases (255^2, 2^2, etc)"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, exponent, expected_arr, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_arr[:len([x for x in input_arr if x != 0 or input_arr.index(x) < len([y for y in input_arr if y != 0])])]}, Exponent: {exponent}")
        
        try:
            # Write inputs
            await write_input_array(dut, input_arr)
            
            # Start computation
            await start_computation(dut, exponent)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            results = await read_output_array(dut)
            
            # Verify results
            for idx in range(ARRAY_SIZE):
                if not is_value_defined(results[idx]):
                    raise TestFailure(f"Result[{idx}] is undefined (X/Z)")
                
                # Get expected value (use 1 for padded elements)
                if idx < len(expected_arr):
                    expected = expected_arr[idx]
                else:
                    expected = 1  # Default for padded zeros
                
                actual = results[idx]
                
                if actual != expected:
                    raise TestFailure(
                        f"Index {idx}: expected {expected}, got {actual} "
                        f"(base={input_arr[idx] if idx < len(input_arr) else 0}, exp={exponent})"
                    )
            
            cocotb.log.info(f"  PASS: All {ARRAY_SIZE} results correct")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")