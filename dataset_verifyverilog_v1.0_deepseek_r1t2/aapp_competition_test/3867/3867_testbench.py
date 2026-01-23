import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
N = 8  # Number of nodes
MAX_CYCLES = 100
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_adjacency(dut, adj):
    """Write adjacency bitmasks to individual ports."""
    for i in range(N):
        port_name = f'adj_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = adj[i]
        else:
            raise TestFailure(f"Adjacency port adj_{i} not found")

async def write_sequence(dut, seq):
    """Write sequence values to individual ports."""
    # Convert to 0-indexed and clamp to 3 bits
    seq_0idx = [x - 1 for x in seq]
    for i in range(N):
        port_name = f'seq_{i}'
        if has_signal(dut, port_name):
            # Use only low 3 bits for node ID
            val = seq_0idx[i] & 0x07 if i < len(seq_0idx) else 0
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f"Sequence port seq_{i} not found")

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

# ============================================================================
# TEST CASES
# ============================================================================

def build_adjacency_from_edges(edges, n=N):
    """Convert edge list to adjacency bitmasks."""
    adj = [0] * n
    for u, v in edges:
        u0 = u - 1  # Convert to 0-indexed
        v0 = v - 1
        if 0 <= u0 < n and 0 <= v0 < n:
            adj[u0] |= (1 << v0)
            adj[v0] |= (1 << u0)
    return adj

# Test case definitions
TEST_CASES = [
    {
        'name': 'Example 1: Valid 1-2-3-4',
        'edges': [(1,2), (1,3), (2,4)],
        'sequence': [1, 2, 3, 4],
        'expected': True
    },
    {
        'name': 'Example 2: Invalid 1-2-4-3',
        'edges': [(1,2), (1,3), (2,4)],
        'sequence': [1, 2, 4, 3],
        'expected': False
    },
    {
        'name': 'Star tree with valid order',
        'edges': [(1,2), (1,3), (1,4), (1,5), (1,6)],
        'sequence': [1, 2, 3, 4, 5, 6],
        'expected': True
    },
    {
        'name': 'Chain of 5 nodes',
        'edges': [(1,2), (2,3), (3,4), (4,5)],
        'sequence': [1, 2, 3, 4, 5],
        'expected': True
    },
    {
        'name': 'Single node',
        'edges': [],
        'sequence': [1],
        'expected': True
    },
    {
        'name': 'Invalid start node',
        'edges': [(1,2), (2,3)],
        'sequence': [2, 1, 3],
        'expected': False
    },
    {
        'name': 'Complex tree with multiple branches',
        'edges': [(1,2), (1,3), (2,4), (2,5), (3,6), (3,7)],
        'sequence': [1, 2, 3, 4, 5, 6, 7],
        'expected': True
    },
    {
        'name': 'Complex tree with wrong child order',
        'edges': [(1,2), (1,3), (2,4), (2,5), (3,6), (3,7)],
        'sequence': [1, 2, 3, 4, 6, 5, 7],
        'expected': False
    }
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_bfs_validator(dut):
    """Test BFS validator with multiple tree structures."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Initial reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for test in TEST_CASES:
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test: {test['name']}")
        cocotb.log.info(f"Edges: {test['edges']}")
        cocotb.log.info(f"Sequence: {test['sequence']}")
        cocotb.log.info(f"Expected: {'Yes' if test['expected'] else 'No'}")
        
        try:
            # Build adjacency bitmasks
            adj = build_adjacency_from_edges(test['edges'])
            
            # Write inputs
            await write_adjacency(dut, adj)
            await write_sequence(dut, test['sequence'])
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=200)
            
            # Read result
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal is undefined (X/Z)")
            
            result = int(dut.valid.value) == 1
            
            if result == test['expected']:
                cocotb.log.info(f"  PASS: Result={'Yes' if result else 'No'}")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: Expected {'Yes' if test['expected'] else 'No'}, got {'Yes' if result else 'No'}")
                failed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"FINAL RESULTS: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
