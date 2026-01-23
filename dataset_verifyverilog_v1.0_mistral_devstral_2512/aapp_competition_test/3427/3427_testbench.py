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
# ARRAY ACCESS HELPERS
# ============================================================================

def pack_edges(edges_list):
    """Pack list of (u,v) edges into 128-bit vector, 16 edges of 8 bits each."""
    packed = 0
    for i, (u, v) in enumerate(edges_list):
        # Map -1 to 8 (outside)
        u_mapped = 8 if u == -1 else u
        v_mapped = 8 if v == -1 else v
        edge_val = (u_mapped << 4) | v_mapped
        packed |= (edge_val << (8 * i))
    return packed

def parse_input(input_str):
    """Parse input string into N, M, and list of edges."""
    lines = input_str.strip().split('\n')
    first_line = lines[0].split()
    N = int(first_line[0])
    M = int(first_line[1])
    edges = []
    for i in range(1, 1 + M):
        parts = lines[i].split()
        u = int(parts[0])
        v = int(parts[1])
        edges.append((u, v))
    return N, M, edges

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_secure_door(dut):
    """Test secure_door module with sample inputs."""
    
    # Test cases: (input_string, expected_output)
    test_cases = [
        (
            "2 3\n-1 0\n-1 1\n0 1\n",
            0
        ),
        (
            "6 8\n-1 0\n-1 1\n0 1\n1 2\n2 3\n3 4\n2 4\n1 5\n",
            3
        )
    ]
    
    # Configuration
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.M.value = 0
    dut.edges.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    failed = 0
    
    for idx, (input_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {idx+1}: {input_str[:30]}...")
        
        try:
            # Parse input
            N, M, edges = parse_input(input_str)
            cocotb.log.info(f"  N={N}, M={M}, edges={edges}")
            
            # Pack edges
            packed_edges = pack_edges(edges)
            
            # Set inputs
            dut.N.value = clamp_to_width(N, 4)
            dut.M.value = clamp_to_width(M, 4)
            dut.edges.value = packed_edges
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            timeout = 10000
            for _ in range(timeout):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")