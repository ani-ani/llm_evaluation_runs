import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Test constants
DATA_WIDTH = 8
OUTPUT_WIDTH = 16
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

# Helper to write array values
def write_array(dut, array_name, values, width):
    """Write values to an array of signals"""
    for i in range(min(len(values), ARRAY_SIZE)):
        if hasattr(dut, f'{array_name}_{i}'):
            getattr(dut, f'{array_name}_{i}').value = clamp_to_width(values[i], width)
        elif hasattr(dut, array_name):
            # Assuming it's a list or array attribute
            dut.__getattr__(array_name)[i].value = clamp_to_width(values[i], width)
        else:
            raise AttributeError(f"Signal {array_name} not found")

# Helper to read array values
def read_array(dut, array_name, width):
    """Read values from an array of signals"""
    values = []
    for i in range(ARRAY_SIZE):
        if hasattr(dut, f'{array_name}_{i}'):
            v = int(getattr(dut, f'{array_name}_{i}').value)
            values.append(v)
        elif hasattr(dut, array_name):
            v = int(dut.__getattr__(array_name)[i].value)
            values.append(v)
        else:
            raise AttributeError(f"Signal {array_name} not found")
    return values

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_array_sum(dut):
    """Test element-wise addition of two arrays"""
    
    # Setup - no clock needed for combinational
    
    # Test cases: (a, b, expected_sum, description)
    test_cases = [
        ([10, 20, 30, 40, 50, 60, 70, 80], 
         [15, 25, 35, 45, 55, 65, 75, 85], 
         [25, 45, 65, 85, 105, 125, 145, 165], 
         "Simple addition"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 
         [9, 10, 11, 12, 13, 14, 15, 16], 
         [10, 12, 14, 16, 18, 20, 22, 24], 
         "Smallest values"),
        ([255, 128, 64, 32, 16, 8, 4, 2], 
         [1, 127, 191, 223, 239, 247, 251, 253], 
         [256, 255, 255, 255, 255, 255, 255, 255], 
         "Edge case - overflow to 16-bit"),
        ([0, 0, 0, 0, 0, 0, 0, 0], 
         [0, 0, 0, 0, 0, 0, 0, 0], 
         [0, 0, 0, 0, 0, 0, 0, 0], 
         "All zeros"),
        ([255, 255, 255, 255, 255, 255, 255, 255], 
         [255, 255, 255, 255, 255, 255, 255, 255], 
         [510, 510, 510, 510, 510, 510, 510, 510], 
         "Maximum values")
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_vals, b_vals, exp_sum, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Write input arrays
            write_array(dut, 'a', a_vals, DATA_WIDTH)
            write_array(dut, 'b', b_vals, DATA_WIDTH)
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read output array
            sum_vals = read_array(dut, 'sum', OUTPUT_WIDTH)
            
            # Verify results
            for j in range(ARRAY_SIZE):
                if sum_vals[j] != exp_sum[j]:
                    raise TestFailure(
                        f"Index {j}: Expected {exp_sum[j]}, got {sum_vals[j]}. "
                        f"Inputs: a[{j}]={a_vals[j]}, b[{j}]={b_vals[j]}"
                    )
            
            cocotb.log.info(f"  PASS: sum = {sum_vals}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")