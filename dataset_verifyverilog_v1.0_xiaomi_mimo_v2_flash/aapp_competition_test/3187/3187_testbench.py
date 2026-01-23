import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 8
SIGNED_WIDTH = 8
ARRAY_SIZE = 8
N_WIDTH = 4
D_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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

def clamp_signed(value, bits):
    """Clamp signed value to fit within specified bit width."""
    min_val = -(1 << (bits - 1))
    max_val = (1 << (bits - 1)) - 1
    return max(min_val, min(max_val, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array_signed(dut, array_name, values, element_width):
    """Write signed values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            # Convert signed value to unsigned representation for assignment
            unsigned_val = from_signed(val, element_width)
            arr[i].value = unsigned_val
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            unsigned_val = from_signed(val, element_width)
            getattr(dut, port_name).value = unsigned_val
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

def read_signed_array(dut, array_name, size, element_width):
    """Read signed array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                unsigned_val = int(arr[i].value)
                results.append(to_signed(unsigned_val, element_width))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(to_signed(int(val), element_width))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

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
# TESTBENCH - MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_protest_optimization(dut):
    """Test the protest optimization module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases with scaled coordinates (0-15 range)
    # Test case 1: 3 citizens, optimal point exists
    test_cases = [
        {
            'name': 'Basic feasible',
            'n': 3,
            'x': [2, 4, 6],
            'y': [2, 4, 6],
            'd': 3,
            'expected_result': 8,  # Sum of distances from (4,4): 4+0+4=8
            'expected_impossible': False
        },
        {
            'name': 'No feasible point',
            'n': 3,
            'x': [0, 10, 20],
            'y': [0, 10, 20],
            'd': 5,
            'expected_result': 0,
            'expected_impossible': True
        },
        {
            'name': 'Single point constraint',
            'n': 2,
            'x': [5, 7],
            'y': [5, 7],
            'd': 2,
            'expected_result': 4,  # Distance from (6,6): 2+2=4
            'expected_impossible': False
        },
        {
            'name': 'Multiple citizens same location',
            'n': 4,
            'x': [3, 3, 3, 3],
            'y': [5, 5, 5, 5],
            'd': 0,
            'expected_result': 0,
            'expected_impossible': False
        },
        {
            'name': 'Boundary test',
            'n': 2,
            'x': [0, 15],
            'y': [0, 15],
            'd': 10,
            'expected_result': 30,  # From (7,8) or similar: 15+15=30
            'expected_impossible': False
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {test_idx+1}: {test['name']}")
        cocotb.log.info(f"{'='*60}")
        
        try:
            # Write inputs
            # Write x coordinates (signed)
            for i in range(test['n']):
                val = test['x'][i]
                unsigned_val = from_signed(val, SIGNED_WIDTH)
                if has_signal(dut, f'x_coords_{i}'):
                    getattr(dut, f'x_coords_{i}').value = unsigned_val
                else:
                    dut.x_coords[i].value = unsigned_val
            
            # Write y coordinates (signed)
            for i in range(test['n']):
                val = test['y'][i]
                unsigned_val = from_signed(val, SIGNED_WIDTH)
                if has_signal(dut, f'y_coords_{i}'):
                    getattr(dut, f'y_coords_{i}').value = unsigned_val
                else:
                    dut.y_coords[i].value = unsigned_val
            
            # Write n (unsigned)
            if has_signal(dut, 'n'):
                dut.n.value = test['n']
            
            # Write d (unsigned)
            if has_signal(dut, 'd'):
                dut.d.value = test['d']
            
            # Wait a bit for values to settle
            await Timer(50, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.done.value):
                raise TestFailure("Done signal is undefined")
            
            if not is_value_defined(dut.impossible.value):
                raise TestFailure("Impossible signal is undefined")
            
            result = safe_int(dut.result.value)
            impossible = int(dut.impossible.value) == 1
            
            # Verify
            if impossible != test['expected_impossible']:
                raise TestFailure(f"Impossible flag mismatch: expected {test['expected_impossible']}, got {impossible}")
            
            if not impossible:
                if result != test['expected_result']:
                    raise TestFailure(f"Result mismatch: expected {test['expected_result']}, got {result}")
            
            cocotb.log.info(f"  PASS: impossible={impossible}, result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST: Verify edge cases with signed values
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_signed_coordinates(dut):
    """Test with negative coordinates."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test with coordinates that include negative values
    # In our 8-bit signed representation, valid range is -128 to 127
    test_cases = [
        {
            'name': 'Negative coordinates',
            'n': 3,
            'x': [-10, 0, 10],
            'y': [-10, 0, 10],
            'd': 15,
            'expected_result': 40,  # From (0,0): 20+0+20=40
            'expected_impossible': False
        }
    ]
    
    for test in test_cases:
        cocotb.log.info(f"Testing: {test['name']}")
        
        # Write coordinates
        for i in range(test['n']):
            # X coordinate
            val = test['x'][i]
            unsigned_val = from_signed(val, SIGNED_WIDTH)
            if has_signal(dut, f'x_coords_{i}'):
                getattr(dut, f'x_coords_{i}').value = unsigned_val
            else:
                dut.x_coords[i].value = unsigned_val
            
            # Y coordinate
            val = test['y'][i]
            unsigned_val = from_signed(val, SIGNED_WIDTH)
            if has_signal(dut, f'y_coords_{i}'):
                getattr(dut, f'y_coords_{i}').value = unsigned_val
            else:
                dut.y_coords[i].value = unsigned_val
        
        if has_signal(dut, 'n'):
            dut.n.value = test['n']
        if has_signal(dut, 'd'):
            dut.d.value = test['d']
        
        await Timer(50, units='ns')
        await start_computation(dut)
        await wait_for_done(dut)
        
        result = safe_int(dut.result.value)
        impossible = int(dut.impossible.value) == 1
        
        if impossible != test['expected_impossible']:
            raise TestFailure(f"Impossible flag mismatch")
        
        if not impossible and result != test['expected_result']:
            raise TestFailure(f"Result mismatch: expected {test['expected_result']}, got {result}")
        
        cocotb.log.info(f"  PASS: result={result}")
