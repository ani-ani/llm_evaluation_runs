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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

def pack_8bit_array(values, max_elements=16):
    """Pack list of up to 16 8-bit values into a 128-bit integer."""
    result = 0
    for i, val in enumerate(values[:max_elements]):
        result |= (val & 0xFF) << (i * 8)
    return result

def pack_friendship_edges(edges, max_edges=32):
    """Pack list of edges into two 160-bit integers (10 bits per endpoint)."""
    packed_a = 0
    packed_b = 0
    for i, (a, b) in enumerate(edges[:max_edges]):
        packed_a |= (a & 0x3FF) << (i * 10)
        packed_b |= (b & 0x3FF) << (i * 10)
    return packed_a, packed_b

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_governor_converter(dut):
    """Test the governor party converter module."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    MAX_CYCLES = 5000
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=5)
    
    # Test cases: (n, m, parties, edges, expected_months, description)
    test_cases = [
        # Example 1: 4 nodes, 3 edges, answer=1
        (
            4, 3,
            [0, 1, 0, 0],  # Parties
            [(1, 2), (2, 3), (2, 4)],  # Edges (1-indexed)
            1,
            "Sample 1: 4 nodes, answer=1"
        ),
        # Example 2: 5 nodes, 4 edges, answer=2
        (
            5, 4,
            [0, 1, 1, 0, 1],
            [(1, 2), (2, 3), (3, 4), (4, 5)],
            2,
            "Sample 2: 5 nodes, answer=2"
        ),
        # Simple case: all same party
        (
            3, 2,
            [0, 0, 0],
            [(1, 2), (2, 3)],
            0,
            "All same party"
        ),
        # Two nodes, different parties
        (
            2, 1,
            [0, 1],
            [(1, 2)],
            1,
            "Two nodes, different parties"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, parties, edges, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  n={n}, m={m}, parties={parties}, edges={edges}")
        
        try:
            # Pack inputs
            n_scaled = min(n, 16)  # Scale down to max 16
            m_scaled = min(m, 32)  # Scale down to max 32 edges
            
            # Pack parties into 128-bit integer (16 x 8-bit)
            # Actually, parties are 1-bit, but we'll use 8-bit for simplicity
            packed_parties = 0
            for j, party in enumerate(parties[:n_scaled]):
                packed_parties |= (party & 0xFF) << (j * 8)
            
            # Pack edges into two 160-bit integers (10 bits per endpoint)
            packed_a = 0
            packed_b = 0
            for j, (a, b) in enumerate(edges[:m_scaled]):
                # Convert to 0-indexed and clamp
                a_idx = max(0, min(a-1, 15))
                b_idx = max(0, min(b-1, 15))
                packed_a |= (a_idx & 0x3FF) << (j * 10)
                packed_b |= (b_idx & 0x3FF) << (j * 10)
            
            # Set inputs
            dut.n.value = n_scaled
            dut.m.value = m_scaled
            dut.initial_parties.value = packed_parties
            dut.friendship_a.value = packed_a
            dut.friendship_b.value = packed_b
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.min_months.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.min_months.value)
            
            # Scale expected for large inputs (if n>16, we can't compute exactly)
            if n > 16:
                # For large graphs, just check it's not 255 (error code)
                if result == 255:
                    raise TestFailure(f"Result is error code (255)")
                # Otherwise, accept any non-error result
                cocotb.log.info(f"  Result (scaled): {result} (expected: {expected} for full graph)")
            else:
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")