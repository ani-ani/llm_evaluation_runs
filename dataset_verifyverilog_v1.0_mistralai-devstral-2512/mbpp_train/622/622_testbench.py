import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 200

def float_to_q8_8(f):
    """Convert float to Q8.8 fixed point integer."""
    return int(f * 256)

def q8_8_to_float(v):
    """Convert Q8.8 fixed point integer to float."""
    # Handle signed conversion if high bit is set
    if v & 0x8000:
        v = v - 0x10000
    return v / 256.0

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_median_two_sorted_lists(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    # Note: Python get_median sums m1+m2 and divides by 2.0
    # HDL needs to implement (m1+m2)/2 scaled to Q8.8
    test_cases = [
        ([1, 12, 15, 26, 38], [2, 13, 17, 30, 45], 5, 16.0),
        ([2, 4, 8, 9], [7, 13, 19, 28], 4, 8.5),
        ([3, 6, 14, 23, 36, 42], [2, 18, 27, 39, 49, 55], 6, 25.0)
    ]
    
    for i, (arr1, arr2, n, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: n={n}, expected={expected}")
        
        # Initialize arrays with zeros
        # We attempt to access dut.arr1[i] which is standard for unpacked arrays in cocotb
        for k in range(ARRAY_SIZE):
            if hasattr(dut, 'arr1'):
                dut.arr1[k].value = 0
            elif hasattr(dut, f'arr1_{k}'):
                getattr(dut, f'arr1_{k}').value = 0
            
            if hasattr(dut, 'arr2'):
                dut.arr2[k].value = 0
            elif hasattr(dut, f'arr2_{k}'):
                getattr(dut, f'arr2_{k}').value = 0
                
        # Fill valid data
        try:
            for k, val in enumerate(arr1):
                if hasattr(dut, 'arr1'):
                    dut.arr1[k].value = clamp_to_width(val, DATA_WIDTH)
                else:
                    getattr(dut, f'arr1_{k}').value = clamp_to_width(val, DATA_WIDTH)
            for k, val in enumerate(arr2):
                if hasattr(dut, 'arr2'):
                    dut.arr2[k].value = clamp_to_width(val, DATA_WIDTH)
                else:
                    getattr(dut, f'arr2_{k}').value = clamp_to_width(val, DATA_WIDTH)
        except Exception as e:
            cocotb.log.error(f"Array assignment failed: {e}")
            raise TestFailure("Failed to assign input arrays.")

        # Drive n
        dut.n.value = n
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
             raise TestFailure("Result signal undefined")
             
        raw_result = int(dut.result.value)
        
        # Convert result back to float
        calculated = q8_8_to_float(raw_result)
        
        cocotb.log.info(f"Test {i+1}: Result (raw)={raw_result}, Calculated={calculated}, Expected={expected}")
        
        # Compare with tolerance for float
        # 0.01 tolerance accounts for Q8.8 precision (approx 0.0039)
        if abs(calculated - expected) > 0.02:
            raise TestFailure(f"Mismatch: Expected {expected}, Got {calculated}")
            
    cocotb.log.info("All tests passed!")