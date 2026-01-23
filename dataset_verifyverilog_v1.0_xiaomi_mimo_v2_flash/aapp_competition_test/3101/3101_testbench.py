import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4
ARRAY_SIZE = 4
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

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
# VERIFICATION HELPERS
# ============================================================================
def is_unsorted(numbers, n):
    """Check if list of n numbers is not non-decreasing."""
    for i in range(n-1):
        if numbers[i] > numbers[i+1]:
            return True
    return False

def count_changes(orig, result, n):
    """Count how many numbers changed and verify single bit flip."""
    changed = 0
    for i in range(n):
        if orig[i] != result[i]:
            changed += 1
            diff = orig[i] ^ result[i]
            # Check if diff has exactly one bit set
            if diff == 0 or (diff & (diff - 1)) != 0:
                raise TestFailure(f"Number {i} changed by multiple bits: {orig[i]} -> {result[i]}")
    if changed != 1:
        raise TestFailure(f"Expected exactly 1 number changed, got {changed}")
    return changed

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_eris_sabotage(dut):
    """Main test for Eris sabotage module."""
    
    # Detect if module has clk and done (sequential)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (n, arr, expected_output, description)
    # If expected_output is None, we expect "impossible"
    test_cases = [
        # Test case 1: Three 4's, change one bit in first number to 5 (unsorted)
        (3, [4, 4, 4], [5, 4, 4], "Three 4's, flip LSB of first"),
        # Test case 2: 1 and 15, no single bit flip makes unsorted
        (2, [1, 15], None, "1 and 15, impossible"),
        # Test case 3: 1,2,3,4, change second 2 to 3 (unsorted)
        (4, [1, 2, 3, 4], [3, 2, 3, 4], "1,2,3,4, flip second number"),
        # Additional test: 2,2,2,2, change last to 3 (unsorted)
        (4, [2, 2, 2, 2], [2, 2, 2, 3], "Four 2's, flip last to 3"),
        # Test case: 0,0,0,0, change first to 1 (unsorted)
        (4, [0, 0, 0, 0], [1, 0, 0, 0], "Four 0's, flip first to 1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, arr, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            arr_clamped = [clamp_to_width(x, DATA_WIDTH) for x in arr]
            
            # Assign to DUT
            if has_signal(dut, 'arr_0'):
                dut.arr_0.value = arr_clamped[0]
                dut.arr_1.value = arr_clamped[1] if len(arr_clamped) > 1 else 0
                dut.arr_2.value = arr_clamped[2] if len(arr_clamped) > 2 else 0
                dut.arr_3.value = arr_clamped[3] if len(arr_clamped) > 3 else 0
            else:
                for idx in range(ARRAY_SIZE):
                    if idx < len(arr_clamped):
                        getattr(dut, f'arr_{idx}').value = arr_clamped[idx]
                    else:
                        getattr(dut, f'arr_{idx}').value = 0
            
            # Write n
            dut.n.value = n
            
            if is_sequential:
                # Start computation
                await start_computation(dut)
                # Wait for done
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read results
            result_vals = []
            for idx in range(ARRAY_SIZE):
                sig_name = f'result_{idx}'
                if has_signal(dut, sig_name):
                    sig = getattr(dut, sig_name)
                    if is_value_defined(sig.value):
                        result_vals.append(int(sig.value))
                    else:
                        result_vals.append(0)
                else:
                    result_vals.append(0)
            
            # Read impossible flag
            impossible = 0
            if has_signal(dut, 'impossible'):
                impossible = int(dut.impossible.value)
            
            # Verify
            if expected is None:
                # Should be impossible
                if impossible != 1:
                    raise TestFailure(f"Expected impossible, but got impossible={impossible}")
                cocotb.log.info(f"  PASS: Correctly output impossible")
            else:
                # Should have a solution
                if impossible == 1:
                    raise TestFailure(f"Expected solution, but got impossible=1")
                
                # Check that result is unsorted
                if not is_unsorted(result_vals[:n], n):
                    raise TestFailure(f"Result {result_vals[:n]} is still sorted")
                
                # Check that exactly one number changed by exactly one bit
                count_changes(arr_clamped[:n], result_vals[:n], n)
                
                cocotb.log.info(f"  PASS: Result {result_vals[:n]} is unsorted (changed one number)")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")