import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_order_by_points(dut):
    """Test the order_by_points module."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to calculate digit sum
    def get_digit_sum(n):
        n = abs(n)
        s = 0
        if n == 0:
            return 0
        while n > 0:
            s += n % 10
            n //= 10
        return s

    # Helper to check result
    async def check_output(expected):
        # Wait for done signal
        max_cycles = 150
        found_done = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                found_done = True
                break
        
        if not found_done:
            raise TestFailure(f"Done signal not asserted within {max_cycles} cycles")
            
        # Read result array
        # Access pattern: dut.result[0], dut.result[1], ...
        actual = []
        for i in range(8):
            val = dut.result[i].value
            if not is_value_defined(val):
                raise TestFailure(f"Output result[{i}] is undefined (X/Z)")
            actual.append(int(val))
            
        # Convert to signed integers
        actual_signed = [x if x < 128 else x - 256 for x in actual]
        
        if actual_signed != expected:
            raise TestFailure(f"Expected {expected}, got {actual_signed}")
        
        dut._log.info(f"Test passed: {actual_signed}")
    
    # Test Case 1: [1, 11, -1, -11, -12] -> [-1, -11, 1, -12, 11]
    # Pad with zeros to fill 8 elements
    inputs1 = [1, 11, -1, -11, -12, 0, 0, 0]
    expected1 = [-1, -11, 1, -12, 11, 0, 0, 0]
    
    # Load inputs
    for i in range(8):
        val = inputs1[i]
        if val < 0:
            val = (256 + val) & 0xFF
        dut.arr[i].value = val
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await check_output(expected1)
    
    # Test Case 2: [1234, 423, 463, 145, 2, 423, 423, 53] (subset of test case 2)
    # 1234=10, 423=9, 463=13, 145=10, 2=2, 53=8
    # Expected sorted by digit sum: 2, 53, 423, 423, 423, 1234, 145, 463
    inputs2 = [1234, 423, 463, 145, 2, 423, 423, 53]
    expected2 = [2, 53, 423, 423, 423, 1234, 145, 463]
    
    # Wait a bit before next start (optional, but safe)
    await RisingEdge(dut.clk)
    
    for i in range(8):
        dut.arr[i].value = inputs2[i]
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await check_output(expected2)
    
    # Test Case 3: Negative numbers [-3, -32, -98, -11, 1, 2, 43, 54]
    # Sums: 3, 5, 17, 2, 1, 2, 7, 9
    # Indices: 0, 1, 2, 3, 4, 5, 6, 7
    # Sorted: 1, 3, 5 (sum 1, 2, 2), 0 (sum 3), 1 (sum 5), 6 (sum 7), 7 (sum 9), 2 (sum 17)
    # Wait, let's re-calculate:
    # 1 (1), -11 (2), 2 (2), -3 (3), -32 (5), 43 (7), 54 (9), -98 (17)
    # Stable: 1 (index 4), -11 (index 3), 2 (index 5), -3 (index 0), -32 (index 1), 43 (index 6), 54 (index 7), -98 (index 2)
    inputs3 = [1, -11, -32, 43, 54, -98, 2, -3]
    expected3 = [1, -11, 2, -3, -32, 43, 54, -98]
    
    await RisingEdge(dut.clk)
    
    for i in range(8):
        val = inputs3[i]
        if val < 0:
            val = (256 + val) & 0xFF
        dut.arr[i].value = val
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await check_output(expected3)
    
    # Test Case 4: Zeros and small values [0, 6, 6, -76, -21, 23, 4, 0]
    # Sums: 0, 6, 6, 13, 3, 5, 4, 0
    # Sorted: 0(0), 0(0), -21(3), 4(4), 23(5), 6(6), 6(6), -76(13)
    # Stable: 0(index 0), 0(index 7), -21(index 4), 4(index 6), 23(index 5), 6(index 1), 6(index 2), -76(index 3)
    inputs4 = [0, 6, 6, -76, -21, 23, 4, 0]
    expected4 = [0, 0, -21, 4, 23, 6, 6, -76]
    
    await RisingEdge(dut.clk)
    
    for i in range(8):
        val = inputs4[i]
        if val < 0:
            val = (256 + val) & 0xFF
        dut.arr[i].value = val
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await check_output(expected4)
