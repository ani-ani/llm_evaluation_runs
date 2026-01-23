import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 32  # Q16.16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def float_to_q8_8(f):
    """Convert float to Q8.8 fixed point"""
    return int(f * 256)

def q8_8_to_float(q):
    """Convert Q8.8 fixed point to float"""
    return q / 256.0

def float_to_q16_16(f):
    """Convert float to Q16.16 fixed point"""
    return int(f * 65536)

def q16_16_to_float(q):
    """Convert Q16.16 fixed point to float"""
    return q / 65536.0

def float_to_fixed(f, frac_bits):
    """Convert float to fixed-point integer"""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits):
    """Convert fixed-point integer to float"""
    return fixed / (1 << frac_bits)

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================
async def write_array(dut, array_name, values, element_width, max_elements=8):
    """Write values to array, handling different interface styles"""
    for i in range(min(len(values), max_elements)):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(values[i], element_width)
        else:
            # Try indexed array
            try:
                arr = getattr(dut, array_name)
                arr[i].value = clamp_to_width(values[i], element_width)
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size, max_elements=8):
    """Read array values"""
    results = []
    for i in range(min(size, max_elements)):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            try:
                arr = getattr(dut, array_name)
                if is_value_defined(arr[i].value):
                    results.append(int(arr[i].value))
                else:
                    results.append(None)
            except (AttributeError, TypeError):
                results.append(None)
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================
async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout"""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal"""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_rain_optimizer(dut):
    """Test rain optimizer module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (d, t, c, r, clouds, roofs, expected_rain)
    # Cloud format: (s, e, p, a)
    # Roof format: (x, y)
    test_cases = [
        # Sample 1: d=20→8, t=60→8, c=2, r=1
        {
            'd': 8, 't': 8, 'c': 2, 'r': 1,
            'clouds': [(5, 8, 0.33333, 30), (6, 8, 0.66666, 70)],  # Scaled times
            'roofs': [(0, 4)],  # Scaled positions
            'expected': 466.662
        },
        # Sample 2: d=3→3, t=4→4, c=2, r=1
        {
            'd': 3, 't': 4, 'c': 2, 'r': 1,
            'clouds': [(1, 3, 0.25, 8), (2, 4, 0.66667, 15)],
            'roofs': [(1, 2)],
            'expected': 10.00005
        },
        # Sample 3: d=3→3, t=4→4, c=1, r=0
        {
            'd': 3, 't': 4, 'c': 1, 'r': 0,
            'clouds': [(0, 2, 0.25, 8)],
            'roofs': [],
            'expected': 2.0
        },
    ]
    
    for test_idx, test in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {test['expected']}")
        
        # Write parameters
        dut.d.value = test['d']
        dut.t.value = test['t']
        dut.c.value = test['c']
        dut.r.value = test['r']
        
        # Write clouds (max 8)
        for i in range(8):
            if i < len(test['clouds']):
                s, e, p, a = test['clouds'][i]
                # Scale times to fit in 0-15 range
                dut.cloud_start[i].value = s
                dut.cloud_end[i].value = e
                dut.cloud_prob[i].value = float_to_q8_8(p)
                dut.cloud_intensity[i].value = a
            else:
                dut.cloud_start[i].value = 0
                dut.cloud_end[i].value = 0
                dut.cloud_prob[i].value = 0
                dut.cloud_intensity[i].value = 0
        
        # Write roofs (max 4)
        for i in range(4):
            if i < len(test['roofs']):
                x, y = test['roofs'][i]
                dut.roof_start[i].value = x
                dut.roof_end[i].value = y
            else:
                dut.roof_start[i].value = 0
                dut.roof_end[i].value = 0
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result_raw = int(dut.result.value)
        result_float = q16_16_to_float(result_raw)
        
        # Allow small absolute error
        expected = test['expected']
        error = abs(result_float - expected)
        
        if error > 0.001:  # Allow 0.001 absolute error
            raise TestFailure(f"Expected {expected:.5f}, got {result_float:.5f} (error: {error:.5f})")
        
        cocotb.log.info(f"  PASS: result = {result_float:.5f}")
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"All {len(test_cases)} tests passed")
