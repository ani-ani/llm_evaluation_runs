import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
IDX_WIDTH = 3
MAX_N = 8
MAX_M = 16
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
# TEST CASES
# ============================================================================

test_cases = [
    {
        "n": 2,
        "m": 1,
        "s": 10,
        "edges": [
            {"u": 0, "v": 1, "t0": 1, "p": 2, "d": 6}
        ],
        "expected": 3,
        "impossible": False,
        "description": "Sample 1: basic"
    },
    {
        "n": 2,
        "m": 1,
        "s": 5,
        "edges": [
            {"u": 0, "v": 1, "t0": 1, "p": 1, "d": 5}
        ],
        "expected": 0,
        "impossible": True,
        "description": "Sample 2: impossible"
    }
]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_latest_departure(dut):
    """Test the latest_departure module with scaled examples."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    for i, tc in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test {i+1}: {tc['description']}")
        dut._log.info(f"{'='*60}")
        
        # Assign problem dimensions
        dut.n.value = tc['n']
        dut.m.value = tc['m']
        dut.s.value = tc['s']
        
        # Assign edge data - element by element (Rule B2)
        for idx, edge in enumerate(tc['edges']):
            # Each signal is a separate array element
            if has_signal(dut, f'u_arr_{idx}'):
                # Individual port style (arr_0, arr_1, ...)
                getattr(dut, f'u_arr_{idx}').value = edge['u']
                getattr(dut, f'v_arr_{idx}').value = edge['v']
                getattr(dut, f't0_arr_{idx}').value = edge['t0']
                getattr(dut, f'p_arr_{idx}').value = edge['p']
                getattr(dut, f'd_arr_{idx}').value = edge['d']
            else:
                # Indexed array style (arr[0], arr[1], ...)
                dut.u_arr[idx].value = edge['u']
                dut.v_arr[idx].value = edge['v']
                dut.t0_arr[idx].value = edge['t0']
                dut.p_arr[idx].value = edge['p']
                dut.d_arr[idx].value = edge['d']
        
        # Start computation
        await start_computation(dut)
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read results
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        if not is_value_defined(dut.impossible.value):
            raise TestFailure(f"Impossible flag is undefined")
        
        result = int(dut.result.value)
        impossible = int(dut.impossible.value) == 1
        
        # Verify
        if impossible != tc['impossible']:
            raise TestFailure(f"Expected impossible={tc['impossible']}, got {impossible}")
        
        if not impossible and result != tc['expected']:
            raise TestFailure(f"Expected result={tc['expected']}, got {result}")
        
        if impossible:
            dut._log.info(f"  PASS: Correctly identified as impossible")
        else:
            dut._log.info(f"  PASS: result={result}")
    
    dut._log.info(f"\n{'='*60}")
    dut._log.info("All tests passed!")
    dut._log.info(f"{'='*60}")
