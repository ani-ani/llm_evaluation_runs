import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 32
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100000

# Fixed-point conversion
Q16_16_SHIFT = 16
MAX_FIXED = (1 << 31) - 1

def float_to_fixed(f):
    """Convert float to Q16.16 fixed-point."""
    if f < 0:
        return from_signed(int(f * (1 << Q16_16_SHIFT)), 32)
    return int(f * (1 << Q16_16_SHIFT))

def fixed_to_float(fixed):
    """Convert Q16.16 fixed-point to float."""
    if fixed & (1 << 31):  # Check if negative (two's complement)
        return (fixed - (1 << 32)) / (1 << Q16_16_SHIFT)
    return fixed / (1 << Q16_16_SHIFT)

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

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Start computation."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_cookie_wall(dut):
    """Test cookie wall hitting problem."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        # Case 1: omega=6, v0=5, theta=45, w=20, vertices: (0,0), (2,0), (1,1.5)
        {
            'n': 3,
            'omega': 6.0,
            'v0': 5.0,
            'theta': 45.0,
            'w': 20.0,
            'x': [0.0, 2.0, 1.0],
            'y': [0.0, 0.0, 1.5],
            'expected_index': 2,
            'expected_time': 5.086781
        },
        # Case 2: omega=0.25, v0=2, theta=45, w=20
        {
            'n': 3,
            'omega': 0.25,
            'v0': 2.0,
            'theta': 45.0,
            'w': 20.0,
            'x': [0.0, 2.0, 1.0],
            'y': [0.0, 0.0, 1.5],
            'expected_index': 1,
            'expected_time': 12.715255
        },
        # Case 3: omega=0, v0=2, theta=0, w=20
        {
            'n': 3,
            'omega': 0.0,
            'v0': 2.0,
            'theta': 0.0,
            'w': 20.0,
            'x': [0.0, 2.0, 1.0],
            'y': [0.0, 0.0, 1.5],
            'expected_index': 2,
            'expected_time': 9.0
        }
    ]
    
    for test_i, test in enumerate(test_cases):
        cocotb.log.info(f"Test case {test_i + 1}: omega={test['omega']}, v0={test['v0']}, theta={test['theta']}, w={test['w']}")
        
        # Set inputs
        dut.n.value = test['n']
        dut.omega.value = float_to_fixed(test['omega'])
        dut.v0.value = float_to_fixed(test['v0'])
        dut.theta.value = float_to_fixed(test['theta'])
        dut.w.value = float_to_fixed(test['w'])
        
        # Set vertex positions
        for i in range(8):
            if i < test['n']:
                setattr(dut, f'x{i}').value = float_to_fixed(test['x'][i])
                setattr(dut, f'y{i}').value = float_to_fixed(test['y'][i])
            else:
                setattr(dut, f'x{i}').value = 0
                setattr(dut, f'y{i}').value = 0
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read results
        result_index = int(dut.result_index.value)
        result_time_fixed = int(dut.result_time.value)
        result_time = fixed_to_float(result_time_fixed)
        
        cocotb.log.info(f"  Result: index={result_index}, time={result_time}")
        cocotb.log.info(f"  Expected: index={test['expected_index']}, time={test['expected_time']}")
        
        # Check index
        if result_index != test['expected_index']:
            raise TestFailure(f"Test {test_i + 1}: Expected index {test['expected_index']}, got {result_index}")
        
        # Check time with absolute error < 0.001
        time_error = abs(result_time - test['expected_time'])
        if time_error > 0.001:
            raise TestFailure(f"Test {test_i + 1}: Time error {time_error} > 0.001")
        
        cocotb.log.info(f"  PASS")
        
        # Wait between tests
        await Timer(100, units='ns')
        await reset_dut(dut)
    
    cocotb.log.info("All tests passed!")
