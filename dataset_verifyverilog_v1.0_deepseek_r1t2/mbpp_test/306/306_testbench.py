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
MAX_CYCLES = 200  # Plenty of cycles for N=8 computation

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

async def write_array(dut, values):
    """Write values to arr_0 through arr_7."""
    for i in range(ARRAY_SIZE):
        if i < len(values):
            port_name = f'arr_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(values[i], DATA_WIDTH)
            else:
                raise TestFailure(f"Missing port: {port_name}")
        else:
            # Pad with zeros
            port_name = f'arr_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = 0

# ============================================================================
# Python Reference Implementation (scaled to N=8)
# ============================================================================

def max_sum_increasing_subseq_ref(a, n, index, k):
    """Reference Python implementation for verification."""
    # dp[i][j] corresponds to max sum of increasing subsequence ending at j
    # with last element from prefix up to i
    dp = [[0 for i in range(n)] for i in range(n)]
    
    for i in range(n):
        if a[i] > a[0]:
            dp[0][i] = a[i] + a[0]
        else:
            dp[0][i] = a[i]
    
    for i in range(1, n):
        for j in range(n):
            if a[j] > a[i] and j > i:
                if dp[i - 1][i] + a[j] > dp[i - 1][j]:
                    dp[i][j] = dp[i - 1][i] + a[j]
                else:
                    dp[i][j] = dp[i - 1][j]
            else:
                dp[i][j] = dp[i - 1][j]
    
    return dp[index][k]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_sum_increasing_subseq(dut):
    """Test the MaxSumIncreasingSubseq module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (array, index, k, expected, description)
    test_cases = [
        ([1, 101, 2, 3, 100, 4, 5], 4, 6, 11, "Test 1: Standard case from problem"),
        ([1, 101, 2, 3, 100, 4, 5], 2, 5, 7, "Test 2: Standard case from problem"),
        ([11, 15, 19, 21, 26, 28, 31], 2, 4, 71, "Test 3: All increasing"),
        ([5, 4, 3, 2, 1], 0, 4, 5, "Test 4: All decreasing"),
        ([1, 2, 3, 4, 5], 2, 4, 12, "Test 5: Simple increasing"),
        ([10, 20, 15, 30, 25], 1, 3, 60, "Test 6: Mixed sequence"),
        ([0, 0, 0, 0, 0], 2, 4, 0, "Test 7: All zeros"),
        ([1, 1, 1, 1, 1], 1, 3, 1, "Test 8: All ones"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (array, index, k, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: a={array[:8]}, index={index}, k={k}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Pad array to 8 elements
            padded_array = array[:ARRAY_SIZE] + [0] * (ARRAY_SIZE - len(array))
            
            # Write inputs
            await write_array(dut, padded_array)
            
            # Set index and k
            if has_signal(dut, 'target_index'):
                dut.target_index.value = index
            else:
                raise TestFailure("Missing target_index signal")
            
            if has_signal(dut, 'target_k'):
                dut.target_k.value = k
            else:
                raise TestFailure("Missing target_k signal")
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify with reference
            ref_result = max_sum_increasing_subseq_ref(padded_array, ARRAY_SIZE, index, k)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result} (ref: {ref_result})")
            
            if result != ref_result:
                raise TestFailure(f"Hardware result {result} doesn't match reference {ref_result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")