import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
N_MAX = 8
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

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

def pack_distance_matrix(dist_matrix):
    """Pack 8x8 distance matrix into 64-bit integer."""
    packed = 0
    for i in range(8):
        for j in range(8):
            dist = dist_matrix[i][j] if i != j else 0
            dist = clamp_to_width(dist, 8)
            packed |= (dist << ((i * 8 + j) * 8))
    return packed

def compute_expected(n, dist_matrix):
    """Compute expected average distance between ports."""
    total_dist = 0
    count = 0
    for i in range(n):
        for j in range(n):
            if i != j:
                total_dist += dist_matrix[i][j]
                count += 1
    
    if count == 0:
        return 0
    
    avg = total_dist / count
    # Convert to Q8.8 fixed-point
    return int(avg * 256)

def reconstruct_matrix_from_input(input_str):
    """Reconstruct full distance matrix from compact input format."""
    lines = input_str.strip().split('\n')
    n = int(lines[0])
    dist_matrix = [[0] * n for _ in range(n)]
    
    line_idx = 1
    for i in range(n):
        if i == n - 1:
            break
        line = list(map(int, lines[line_idx].split()))
        line_idx += 1
        for j_idx, dist in enumerate(line):
            j = i + 1 + j_idx
            dist_matrix[i][j] = dist
            dist_matrix[j][i] = dist
    
    return n, dist_matrix

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tree_avg_dist(dut):
    """Test tree average distance calculator."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem
    test_inputs = [
        "3\n4 4\n2\n",
        "4\n2 2 2\n2 2\n2\n"
    ]
    
    # Expected answers (Q8.8 format)
    # For test 1: expected average = 2.13333333333333
    # For test 2: expected average = 1.6
    # Convert to Q8.8: multiply by 256
    expected_q88 = [
        int(2.13333333333333 * 256),
        int(1.6 * 256)
    ]
    
    for test_idx, (input_str, expected) in enumerate(zip(test_inputs, expected_q88)):
        cocotb.log.info(f"Running test case {test_idx + 1}")
        
        # Parse input
        n, dist_matrix = reconstruct_matrix_from_input(input_str)
        
        # Pack matrix
        packed_matrix = pack_distance_matrix(dist_matrix)
        
        # Load inputs
        dut.n.value = n
        dut.dist_matrix.value = packed_matrix
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {test_idx+1}: result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            raise TestFailure(
                f"Test {test_idx+1}: Expected {expected} (0x{expected:04X}), "
                f"got {result} (0x{result:04X})"
            )
        
        cocotb.log.info(f"Test {test_idx+1} PASS: result = {result} (0x{result:04X})")
    
    cocotb.log.info("All tests passed!")
