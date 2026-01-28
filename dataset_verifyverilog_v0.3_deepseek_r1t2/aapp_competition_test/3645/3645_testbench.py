import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_guess_circle(dut):
    # Test cases: (n, values_list, expected_output_list)
    test_cases = [
        (3, [1,2,3], [1,2,3]),
        (3, [1,1,2], []),
        (4, [1,2,1,3], []),
        (5, [1,2,3,4,1], [1]),
    ]
    
    for i, (n, values_list, expected) in enumerate(test_cases):
        # Set n
        dut.n.value = n
        
        # Initialize values array to zeros
        for idx in range(16):
            dut.values[idx].value = 0
        
        # Set actual values
        for idx, val in enumerate(values_list):
            if idx < 16:
                dut.values[idx].value = val
        
        # Wait for combinational propagation
        await Timer(100, units='ns')
        
        # Read result
        count = int(dut.count.value)
        result_vals = []
        for idx in range(16):
            if is_value_defined(dut.result[idx].value):
                result_vals.append(int(dut.result[idx].value))
            else:
                result_vals.append(0)
        
        actual = result_vals[:count]
        actual.sort()
        
        # Compare
        if expected:
            expected_sorted = sorted(expected)
            if actual != expected_sorted:
                raise TestFailure(f"Test {i}: expected {expected_sorted}, got {actual}")
        else:
            if count != 0:
                raise TestFailure(f"Test {i}: expected none, got {actual}")
        
        dut._log.info(f"Test {i} passed")