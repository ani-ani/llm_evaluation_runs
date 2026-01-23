import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 8
MAX_M = 16
MAX_P = 8
DATA_WIDTH = 4          # for node IDs
COST_WIDTH = 16
CLK_PERIOD_NS = 10

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

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# TEST CASE DEFINITIONS
# ============================================================================

TEST_CASES = [
    # (n, p, insecure_list, edges, expected_result, expected_impossible, description)
    (4, 1, [1], [(1,2,1),(1,3,1),(1,4,1),(2,3,2),(2,4,4),(3,4,3)], 6, False, "Sample 1"),
    (4, 2, [1,2], [(1,2,1),(2,3,7),(3,4,5)], 0, True, "Sample 2"),
    (1, 1, [1], [], 0, False, "Single node"),
    (2, 2, [1,2], [(1,2,5)], 5, False, "Two insecure with edge"),
    (2, 2, [1,2], [], 0, True, "Two insecure no edge"),
    (2, 0, [], [(1,2,5)], 5, False, "Two secure"),
    (3, 0, [], [(1,2,1),(2,3,2)], 3, False, "Three secure connected"),
    (3, 0, [], [(1,2,1)], 0, True, "Three secure disconnected"),
    (3, 1, [3], [(1,2,1),(1,3,2),(2,3,3)], 3, False, "One insecure leaf"),
    (3, 1, [3], [(1,2,1)], 0, True, "One insecure isolated"),
    (3, 2, [2,3], [(1,2,1),(1,3,2)], 3, False, "Two insecure both leaves"),
    (3, 2, [2,3], [(2,3,1)], 0, True, "Two insecure no secure connection"),
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_secure_network(dut):
    """Test the SecureNetwork module with all defined test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, (n, p, insecure_list, edges, expected_result, expected_impossible, desc) in enumerate(TEST_CASES):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Pack inputs
            # n and p
            dut.n.value = n
            dut.p.value = p
            
            # insecure_list (pack into 32-bit)
            insecure_packed = 0
            for idx, node in enumerate(insecure_list):
                insecure_packed |= (node & 0xF) << (idx * 4)
            dut.insecure_list.value = insecure_packed
            
            # edges: pack u, v, cost, valid
            edge_u_packed = 0
            edge_v_packed = 0
            edge_cost_packed = 0
            edge_valid_packed = 0
            for idx, (u, v, cost) in enumerate(edges):
                edge_u_packed |= (u & 0xF) << (idx * 4)
                edge_v_packed |= (v & 0xF) << (idx * 4)
                edge_cost_packed |= (cost & 0xFFFF) << (idx * 16)
                edge_valid_packed |= (1 << idx)
            dut.edge_u.value = edge_u_packed
            dut.edge_v.value = edge_v_packed
            dut.edge_cost.value = edge_cost_packed
            dut.edge_valid.value = edge_valid_packed
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            if not is_value_defined(dut.impossible.value):
                raise TestFailure("impossible signal undefined")
            impossible = bool(int(dut.impossible.value))
            
            if not is_value_defined(dut.result.value):
                result = 0
            else:
                result = int(dut.result.value)
            
            # Verify
            if impossible != expected_impossible:
                raise TestFailure(f"Expected impossible={expected_impossible}, got {impossible}")
            
            if not impossible and result != expected_result:
                raise TestFailure(f"Expected result={expected_result}, got {result}")
            
            cocotb.log.info(f"  PASS: result={result}, impossible={impossible}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
