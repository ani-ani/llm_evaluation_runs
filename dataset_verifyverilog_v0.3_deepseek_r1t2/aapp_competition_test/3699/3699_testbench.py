import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
RESULT_WIDTH = 64
ARRAY_SIZE = 8
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Fixed-point conversion (Q16.16)
def float_to_fixed(f, frac_bits=16):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=16):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

# Distance calculation in Python (for expected results)
import math

def calc_distance_py(x1, y1, x2, y2):
    return math.sqrt((x1 - x2)**2 + (y1 - y2)**2)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
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
# ARRAY WRITE HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    for i, val in enumerate(values):
        port_name = f"{array_name}[{i}]"
        if has_signal(dut, port_name):
            attr = getattr(dut, array_name)
            attr[i].value = clamp_to_width(val, element_width)
        else:
            # Try individual ports
            port_name = f"{array_name}_{i}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(val, element_width)
            else:
                raise TestFailure(f"Cannot find array port: {array_name}[{i}]")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_recycling_optimization(dut):
    """Test the recycling optimization module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem examples
    test_cases = [
        # Test case 1: First example
        {
            'ax': 3, 'ay': 1,
            'bx': 1, 'by': 2,
            'tx': 0, 'ty': 0,
            'bottles': [(1, 1), (2, 1), (2, 3)],
            'expected': 11.084259940083
        },
        # Test case 2: Second example  
        {
            'ax': 5, 'ay': 0,
            'bx': 4, 'by': 2,
            'tx': 2, 'ty': 0,
            'bottles': [(5, 2), (3, 0), (5, 5), (3, 5), (3, 3)],
            'expected': 33.121375178000
        },
        # Additional test cases
        {
            'ax': 1, 'ay': 1,
            'bx': 100, 'by': 100,
            'tx': 0, 'ty': 0,
            'bottles': [(2, 2)],
            'expected': 2.828427124746  # sqrt(2)*2, but optimized
        },
        {
            'ax': 0, 'ay': 0,
            'bx': 1000, 'by': 1000,
            'tx': 500, 'ty': 500,
            'bottles': [(500, 501), (501, 500)],
            'expected': 2.0  # Both close to bin
        }
    ]
    
    for test_idx, test in enumerate(test_cases):
        cocotb.log.info(f"\n=== Test Case {test_idx + 1} ===")
        cocotb.log.info(f"Adil: ({test['ax']}, {test['ay']}), Bera: ({test['bx']}, {test['by']}), Bin: ({test['tx']}, {test['ty']})")
        cocotb.log.info(f"Bottles: {test['bottles']}")
        
        # Convert coordinates to fixed-point
        ax_fx = float_to_fixed(test['ax'])
        ay_fx = float_to_fixed(test['ay'])
        bx_fx = float_to_fixed(test['bx'])
        by_fx = float_to_fixed(test['by'])
        tx_fx = float_to_fixed(test['tx'])
        ty_fx = float_to_fixed(test['ty'])
        
        # Write coordinates
        dut.ax.value = ax_fx
        dut.ay.value = ay_fx
        dut.bx.value = bx_fx
        dut.by.value = by_fx
        dut.tx.value = tx_fx
        dut.ty.value = ty_fx
        
        # Write number of bottles
        dut.num_bottles.value = len(test['bottles'])
        
        # Write bottle coordinates
        for i, (x, y) in enumerate(test['bottles']):
            dut.bottle_x[i].value = float_to_fixed(x)
            dut.bottle_y[i].value = float_to_fixed(y)
        
        # Pad remaining bottle slots with zeros
        for i in range(len(test['bottles']), ARRAY_SIZE):
            dut.bottle_x[i].value = 0
            dut.bottle_y[i].value = 0
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read result
        if is_value_defined(dut.total_distance.value):
            result_fixed = int(dut.total_distance.value)
            result_float = fixed_to_float(result_fixed)
            
            # Calculate expected result
            expected = test['expected']
            
            # Check with tolerance
            tolerance = 0.01  # 1% tolerance for fixed-point approximation
            abs_diff = abs(result_float - expected)
            rel_diff = abs_diff / max(1.0, expected)
            
            if rel_diff > tolerance and abs_diff > 0.1:
                raise TestFailure(
                    f"Test {test_idx + 1} FAILED: Expected {expected:.6f}, got {result_float:.6f} "
                    f"(diff: {abs_diff:.6f}, rel: {rel_diff:.6f})"
                )
            else:
                cocotb.log.info(f"  PASS: Result = {result_float:.6f} (expected: {expected:.6f})")
        else:
            raise TestFailure(f"Test {test_idx + 1}: Result is undefined (X/Z)")
    
    cocotb.log.info("\n" + "="*50)
    cocotb.log.info("ALL TESTS PASSED")
