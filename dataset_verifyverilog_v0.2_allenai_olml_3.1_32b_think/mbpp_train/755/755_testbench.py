import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper to convert signed decimal to 16-bit hex for testbench
def to_hex(val):
    if val < 0:
        return (1 << 16) + val
    return val

@cocotb.test()
async def test_second_smallest(dut):
    """Test the second_smallest module with various cases"""
    
    # Test Case 1: [1, 2, -8, -2, 0, -2] -> -2
    # Python set: {-8, -2, 0, 1, 2} -> sorted [-8, -2, 0, 1, 2] -> second is -2
    # We need to fill the 8 inputs. Let's add duplicates (0, -2) and a large number (100) at the end
    # Input array: [1, 2, -8, -2, 0, -2, 0, 100]
    # Sorted: [-8, -2, -2, 0, 0, 1, 2, 100]
    # Min is -8. First value > -8 is -2. Correct.
    dut.in0.value = 1
    dut.in1.value = 2
    dut.in2.value = -8
    dut.in3.value = -2
    dut.in4.value = 0
    dut.in5.value = -2
    dut.in6.value = 0
    dut.in7.value = 100
    
    await Timer(1, units='ns')
    
    expected = to_hex(-2)
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Test Case 1 Failed: Expected {expected:04X}, got {actual:04X}")
    print(f"Test Case 1 Passed: Result {actual:04X} ({actual if actual < 32768 else actual - 65536})")

    # Test Case 2: [1, 1, -0.5, 0, 2, -2, -2] -> -0.5
    # Since we are using integers, we scale inputs by 10 (multiply by 10 to keep precision)
    # Scaled inputs: [10, 10, -5, 0, 20, -20, -20, 50] (added 50 as padding)
    # Python logic on scaled: set = { -20, -5, 0, 10, 20, 50 } -> sorted -> second is -5
    # Hardware should find first value > min. Min is -20. First > -20 is -5.
    dut.in0.value = 10
    dut.in1.value = 10
    dut.in2.value = -5
    dut.in3.value = 0
    dut.in4.value = 20
    dut.in5.value = -20
    dut.in6.value = -20
    dut.in7.value = 50
    
    await Timer(1, units='ns')
    
    expected = to_hex(-5)
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Test Case 2 Failed: Expected {expected:04X}, got {actual:04X}")
    print(f"Test Case 2 Passed: Result {actual:04X} ({actual if actual < 32768 else actual - 65536})")

    # Test Case 3: [2, 2] -> None (represented as 0xFFFF)
    # Inputs: [2, 2, 2, 2, 2, 2, 2, 2]
    dut.in0.value = 2
    dut.in1.value = 2
    dut.in2.value = 2
    dut.in3.value = 2
    dut.in4.value = 2
    dut.in5.value = 2
    dut.in6.value = 2
    dut.in7.value = 2
    
    await Timer(1, units='ns')
    
    expected = 0xFFFF
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Test Case 3 Failed: Expected {expected:04X}, got {actual:04X}")
    print(f"Test Case 3 Passed: Result {actual:04X} (None)")

    # Test Case 4: [2, 2, 2] -> None
    # Inputs: [2, 2, 2, 2, 2, 2, 2, 2] (Same as above effectively)
    # Let's try a mix that ensures valid input but all unique are same: [5, 5, 5, 5, 5, 5, 5, 5]
    dut.in0.value = 5
    dut.in1.value = 5
    dut.in2.value = 5
    dut.in3.value = 5
    dut.in4.value = 5
    dut.in5.value = 5
    dut.in6.value = 5
    dut.in7.value = 5
    
    await Timer(1, units='ns')
    
    expected = 0xFFFF
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Test Case 4 Failed: Expected {expected:04X}, got {actual:04X}")
    print(f"Test Case 4 Passed: Result {actual:04X} (None)")
    
    print(f"Summary: All 4 tests passed.")