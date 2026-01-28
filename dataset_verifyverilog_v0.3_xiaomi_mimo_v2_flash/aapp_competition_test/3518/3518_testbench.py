import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Match HDL parameters
# ============================================================================
MAX_STUDENTS = 8
MAX_EDGES = 16
DATA_WIDTH = 8
COST_WIDTH = 20
RESULT_WIDTH = 24
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    # Set all control signals to safe state
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'edge_valid'):
        dut.edge_valid.value = 0
    if has_signal(dut, 'edge_done'):
        dut.edge_done.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout, handling X/Z values."""
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

async def send_edge(dut, p, q, cost):
    """Send one edge to the DUT using individual signals."""
    dut.p.value = clamp_to_width(p, DATA_WIDTH)
    dut.q.value = clamp_to_width(q, DATA_WIDTH)
    dut.cost.value = clamp_to_width(cost, COST_WIDTH)
    dut.edge_valid.value = 1
    await RisingEdge(dut.clk)
    dut.edge_valid.value = 0
    # Wait one cycle between edges for stability
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST - COCOTB ENTRY POINT
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_global_warming_solver(dut):
    """Comprehensive test for global warming solver module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Initial reset
    await reset_dut(dut)
    
    # Define test cases: edges and expected results
    test_cases = [
        {
            'name': 'Test 1: Impossible (odd component)',
            'edges': [
                (3, 1, 375),
                (2, 5, 283),
                (1, 4, 716),
                (3, 4, 98)
            ],
            'expected_impossible': True,
            'expected_cost': 0
        },
        {
            'name': 'Test 2: Possible (two components)',
            'edges': [
                (5, 6, 600),
                (2, 5, 200),
                (3, 5, 400),
                (6, 3, 500),
                (1, 4, 300),
                (3, 2, 400),
                (6, 2, 200)
            ],
            'expected_impossible': False,
            'expected_cost': 900
        },
        {
            'name': 'Test 3: Single pair',
            'edges': [(1, 2, 100)],
            'expected_impossible': False,
            'expected_cost': 100
        },
        {
            'name': 'Test 4: Multiple small components',
            'edges': [
                (1, 2, 50),
                (3, 4, 75),
                (5, 6, 120),
                (7, 8, 90)
            ],
            'expected_impossible': False,
            'expected_cost': 335
        },
        {
            'name': 'Test 5: No edges',
            'edges': [],
            'expected_impossible': True,
            'expected_cost': 0
        },
        {
            'name': 'Test 6: Larger component (size 6)',
            'edges': [
                (1, 2, 10),
                (2, 3, 20),
                (3, 4, 30),
                (4, 5, 40),
                (5, 6, 50),
                (1, 6, 15),
                (2, 5, 25)
            ],
            'expected_impossible': False,
            'expected_cost': 70  # (1,6)=15, (2,5)=25, (3,4)=30 = 70
        }
    ]
    
    # Track overall results
    total_passed = 0
    total_failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"\n{'='*70}")
        cocotb.log.info(f"Running: {test['name']}")
        cocotb.log.info(f"Expected: impossible={test['expected_impossible']}, cost={test['expected_cost']}")
        cocotb.log.info(f"{'='*70}")
        
        try:
            # Start computation
            await start_computation(dut)
            
            # Send all edges
            for p, q, cost in test['edges']:
                await send_edge(dut, p, q, cost)
                cocotb.log.info(f"  Sent edge: {p}-{q} cost={cost}")
            
            # Signal end of edge input
            dut.edge_done.value = 1
            await RisingEdge(dut.clk)
            dut.edge_done.value = 0
            
            # Wait for computation to complete
            await wait_for_done(dut)
            
            # Read results with safety checks
            if not is_value_defined(dut.impossible.value):
                raise TestFailure("impossible signal is undefined (X/Z)")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("result signal is undefined (X/Z)")
            
            impossible = bool(int(dut.impossible.value))
            result = int(dut.result.value)
            
            # Verify results
            if impossible != test['expected_impossible']:
                raise TestFailure(
                    f"impossible mismatch: expected {test['expected_impossible']}, got {impossible}"
                )
            
            if not impossible and result != test['expected_cost']:
                raise TestFailure(
                    f"cost mismatch: expected {test['expected_cost']}, got {result}"
                )
            
            cocotb.log.info(f"  PASS: impossible={impossible}, cost={result}")
            total_passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            total_failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    # Final summary
    cocotb.log.info(f"\n{'='*70}")
    cocotb.log.info(f"FINAL RESULTS: {total_passed}/{total_passed+total_failed} tests passed")
    cocotb.log.info(f"{'='*70}")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} test(s) failed")