import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 10  # Bits per edge: 2 for c, 4 for b, 4 for a
ARRAY_SIZE = 16  # Maximum edges
MAX_N = 8        # Maximum nodes
MAX_M = 16       # Maximum edges
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000  # Allow enough cycles for 2^8 * 16 checks = 4096 iterations

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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

def pack_edge(a, b, c):
    """Pack edge data into 10-bit value: [9:8]=c, [7:4]=b, [3:0]=a"""
    # Clamp to ensure values fit
    a_clamped = a & 0xF  # 4 bits
    b_clamped = b & 0xF  # 4 bits
    c_clamped = c & 0x3  # 2 bits
    return (c_clamped << 8) | (b_clamped << 4) | a_clamped

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_lounge_assigner(dut):
    """Test lounge assigner with multiple test cases."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, m, edges_list, expected_result, is_impossible, description)
    # edges_list contains tuples: (a, b, c)
    test_cases = [
        (
            4, 4,
            [(1, 2, 2), (2, 3, 1), (3, 4, 1), (4, 1, 2)],
            3, False,
            "Sample 1: 4 airports, 4 routes"
        ),
        (
            5, 5,
            [(1, 2, 1), (2, 3, 1), (2, 4, 1), (2, 5, 1), (4, 5, 1)],
            0, True,
            "Sample 2: impossible case"
        ),
        (
            4, 5,
            [(1, 2, 1), (2, 3, 0), (2, 4, 1), (3, 1, 1), (3, 4, 1)],
            2, False,
            "Sample 3: 4 airports, 5 routes"
        ),
        (
            3, 3,
            [(1, 2, 1), (2, 3, 1), (1, 3, 1)],
            0, True,
            "Small cycle: XOR triangle (impossible)"
        ),
        (
            2, 1,
            [(1, 2, 2)],
            2, False,
            "Simple: both must have lounges"
        ),
        (
            2, 1,
            [(1, 2, 0)],
            0, False,
            "Simple: no lounges"
        ),
        (
            1, 0,
            [],
            0, False,
            "Single airport, no routes"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, edges, expected, should_be_impossible, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  n={n}, m={m}, edges={edges}")
        
        try:
            # Set n and m
            dut.n.value = n
            dut.m.value = m
            
            # Pack and write edges
            for edge_idx, (a, b, c) in enumerate(edges):
                packed = pack_edge(a, b, c)
                port_name = f'edge_{edge_idx}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = packed
                else:
                    raise TestFailure(f"Signal {port_name} not found")
            
            # Zero out unused edges
            for edge_idx in range(len(edges), 16):
                port_name = f'edge_{edge_idx}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = 0
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.done.value):
                raise TestFailure("Done signal undefined")
            
            result_val = int(dut.result.value)
            impossible_val = int(dut.impossible.value)
            
            # Verify
            if should_be_impossible:
                if impossible_val != 1:
                    raise TestFailure(f"Expected impossible=1, got {impossible_val}")
                cocotb.log.info(f"  PASS: correctly identified as impossible")
            else:
                if impossible_val == 1:
                    raise TestFailure(f"Expected possible, got impossible")
                if result_val != expected:
                    raise TestFailure(f"Expected {expected}, got {result_val}")
                cocotb.log.info(f"  PASS: result = {result_val}")
            
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