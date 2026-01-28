import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def special_filter_python(nums):
    """Python reference implementation."""
    count = 0
    for num in nums:
        abs_num = abs(num)
        if abs_num > 10:
            last_digit = abs_num % 10
            first_digit = abs_num
            while first_digit >= 10:
                first_digit //= 10
            if (first_digit % 2 == 1) and (last_digit % 2 == 1):
                count += 1
    return count

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_special_filter(dut):
    """Test special_filter module."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        if hasattr(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = 0
        elif hasattr(dut.arr, '__len__') and len(dut.arr) > i:
            dut.arr[i].value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([5, -2, 1, -5], 0),
        ([15, -73, 14, -15], 1),
        ([33, -2, -3, 45, 21, 109], 2),
        ([43, -12, 93, 125, 121, 109], 4),
        ([71, -2, -33, 75, 21, 19], 3),
        ([1], 0),
        ([], 0),
        ([13], 1),
        ([99], 1),
        ([-11], 1),
        ([22], 0),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_array, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: {input_array} -> expected {expected}")
        
        # Set length
        dut.len.value = len(input_array)
        
        # Set array elements
        for j in range(8):
            if j < len(input_array):
                num = input_array[j]
                if num < 0:
                    val = (1 << 8) + num  # Two's complement for 8-bit
                else:
                    val = num
                # Try both array access patterns
                if hasattr(dut, f'arr_{j}'):
                    getattr(dut, f'arr_{j}').value = val
                elif hasattr(dut.arr, '__len__') and len(dut.arr) > j:
                    dut.arr[j].value = val
            else:
                if hasattr(dut, f'arr_{j}'):
                    getattr(dut, f'arr_{j}').value = 0
                elif hasattr(dut.arr, '__len__') and len(dut.arr) > j:
                    dut.arr[j].value = 0
        
        await Timer(5, units='ns')
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        done_received = False
        max_cycles = 150
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Test {i+1}: done signal not asserted after {max_cycles} cycles")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: result has X/Z values")
        
        actual = int(dut.result.value)
        
        if actual != expected:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {actual}")
        
        passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
