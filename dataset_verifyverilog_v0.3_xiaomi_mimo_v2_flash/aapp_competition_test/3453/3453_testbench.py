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
DATA_WIDTH = 8      # For node indices (A, B)
RESULT_WIDTH = 32   # For danger levels
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# PACKING HELPER FOR EDGES
# ============================================================================

def pack_edges(edges_list, M, M_MAX=16):
    """Pack list of edges into single integer for packed array input.
    Each edge: [39:36]=A, [35:32]=B, [31:0]=L
    """
    packed = 0
    for i, (A, B, L) in enumerate(edges_list):
        # Pack as {A[3:0], B[3:0], L[31:0]} -> 40 bits
        edge_val = (A << 36) | (B << 32) | L
        packed |= (edge_val << (40 * i))
    return packed

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_spike_cave(dut):
    """Test the spike_cave module with scaled-down graphs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases with scaled graphs
    test_cases = [
        # Original example scaled down (5 nodes)
        (
            5, 5,
            [(1,2,3), (1,4,8), (2,3,12), (3,5,4), (4,5,2)],
            [35, 39, 36, 27, 29]
        ),
        # Second example scaled down (7 nodes)
        (
            7, 6,
            [(1,2,8), (1,3,15), (1,4,10), (3,5,40), (3,6,3), (5,7,60)],
            [221, 261, 206, 271, 326, 221, 626]
        ),
        # Small test case (3 nodes)
        (
            3, 2,
            [(1,2,5), (2,3,10)],
            [15, 10, 15]
        ),
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, (N, M, edges, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest case {tc_idx+1}: N={N}, M={M}")
        
        # Pack edges
        packed_edges = pack_edges(edges, M)
        
        # Set inputs
        dut.N.value = N
        dut.M.value = M
        dut.edges.value = packed_edges
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for cycle in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            dut._log.error(f"Test {tc_idx+1}: Timeout waiting for done")
            failed += 1
            continue
        
        # Read danger values from array
        danger_values = []
        for i in range(N):
            # Access individual array elements
            if is_value_defined(dut.danger[i].value):
                danger_values.append(int(dut.danger[i].value))
            else:
                danger_values.append(None)
        
        # Compare with expected
        success = True
        for i, (got, exp) in enumerate(zip(danger_values, expected)):
            if got is None:
                dut._log.error(f"Test {tc_idx+1}, node {i+1}: got undefined value")
                success = False
            elif got != exp:
                dut._log.error(f"Test {tc_idx+1}, node {i+1}: got {got}, expected {exp}")
                success = False
        
        if success:
            dut._log.info(f"Test {tc_idx+1}: PASS")
            passed += 1
        else:
            failed += 1
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")