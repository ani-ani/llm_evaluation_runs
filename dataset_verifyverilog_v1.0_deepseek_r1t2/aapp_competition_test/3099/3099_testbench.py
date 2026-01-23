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
# CONFIGURATION
# ============================================================================

N = 4                     # Number of spies in test cases
DATA_WIDTH = N            # Width of enemy_mask and good masks
ADJ_WIDTH = N * N         # Width of adjacency matrix
CLK_PERIOD_NS = 10        # Clock period in ns
MAX_CYCLES = 10000        # Timeout for computation

# ============================================================================
# HELPER FUNCTIONS FOR TESTBENCH
# ============================================================================

def pack_adj_matrix(edges, N):
    """Pack list of (u,v) edges into a flattened N*N-bit adjacency matrix."""
    adj = 0
    for u, v in edges:
        adj |= 1 << (u * N + v)
    return adj

def pack_enemy_mask(enemies, N):
    """Pack list of enemy indices into an N-bit mask."""
    mask = 0
    for e in enemies:
        mask |= 1 << e
    return mask

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout, handling X/Z values."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_spy_message_minimizer(dut):
    """Test the spy message minimizer module with the three example cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (edges, enemies, expected_result)
    test_cases = [
        # Case 1: 4 spies, enemy 1, edges 0->1,1->2,2->3
        ([(0,1), (1,2), (2,3)], [1], 2),
        # Case 2: 4 spies, no enemies, edges 0->2,0->1,2->1,2->3
        ([(0,2), (0,1), (2,1), (2,3)], [], 1),
        # Case 3: 4 spies, enemies 1,2, edges 0->1,0->2,0->3,1->3,2->3
        ([(0,1), (0,2), (0,3), (1,3), (2,3)], [1,2], 2),
    ]
    
    for case_idx, (edges, enemies, expected) in enumerate(test_cases):
        dut._log.info(f"Running test case {case_idx+1}: edges={edges}, enemies={enemies}, expected={expected}")
        
        # Pack inputs
        enemy_mask = pack_enemy_mask(enemies, N)
        adj_matrix = pack_adj_matrix(edges, N)
        
        # Apply inputs
        dut.enemy_mask.value = enemy_mask
        dut.adj_matrix.value = adj_matrix
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=MAX_CYCLES)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z) for test {case_idx+1}")
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {case_idx+1} failed: expected {expected}, got {result}")
        else:
            dut._log.info(f"Test {case_idx+1} passed: result = {result}")
    
    dut._log.info("All tests passed!")

# Note: The testbench assumes the Verilog module uses N=4.
# The module must be instantiated with the same parameter.
# For simulation, the Verilog code can be compiled with N=4.
