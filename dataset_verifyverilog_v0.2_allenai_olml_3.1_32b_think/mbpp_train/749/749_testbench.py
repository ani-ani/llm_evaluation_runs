import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_sort_numeric_strings(dut):
    """Test sorting of numeric strings (adapted to integer array)"""
    
    # Create a clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.nums.value = 0  # Reset array input
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to set array input
    def set_input(arr):
        # Convert Python list of strings/ints to logic values
        # Assuming input array is 16 elements, [0] is 0th element in bit vector array
        # Verilog unpacking: array_name[i] maps to bit slices
        # In cocotb, if Verilog is reg [7:0] nums [0:15], dut.nums[i].value = val
        
        # Ensure array is length 16, pad with 0s if needed (or clamp values)
        padded_arr = arr + [0] * (16 - len(arr))
        
        # Handle values outside 8-bit signed range (-128 to 127)
        for i, val in enumerate(padded_arr):
            ival = int(val)
            if ival > 127:  # Clamping positive overflow to 127
                ival = 127
            elif ival < -128: # Clamping negative overflow to -128
                ival = -128
            
            # Cocotb setting for unpacked array
            # Note: Access syntax depends on simulator, but usually dut.array_name[i].value
            dut.nums[i].value = ival
            
    # Helper to get output
    def get_output():
        result = []
        for i in range(16):
            # Read signed value
            val = dut.sorted_nums[i].value.signed_integer
            result.append(val)
        return result

    # --- Test Case 1 ---
    # Input: ['4','12','45','7','0','100','200','-12','-500']
    # Python Result: [-500, -12, 0, 4, 7, 12, 45, 100, 200]
    # Hardware Adaption: 
    # -500 -> -128 (clamped), 200 -> 127 (clamped) 
    # Expected HW: [-128, -12, 0, 4, 7, 12, 45, 100, 127, 0, 0...]
    
    dut._log.info("Running Test Case 1 (Adapted)")
    input_1 = [4, 12, 45, 7, 0, 100, 200, -12, -500]
    
    # Load input
    set_input(input_1)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 300
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done signal")
        
    # Check result
    result_1 = get_output()
    # Determine expected (9 active elements sorted)
    # Hardware clamps -500 to -128, 200 to 127
    # Sorted: -128, -12, 0, 4, 7, 12, 45, 100, 127
    expected_1 = [-128, -12, 0, 4, 7, 12, 45, 100, 127] + [0]*7
    
    if result_1 != expected_1:
        raise TestFailure(f"Test 1 Failed: Got {result_1}, Expected {expected_1}")
    dut._log.info(f"Test 1 Passed: {result_1[:9]}")
    
    # --- Test Case 2 ---
    # Input: ['2','3','8','4','7','9','8','2','6','5','1','6','1','2','3','4','6','9','1','2']
    # Hardware Input: First 16 elements
    # Python logic: sort these 16 numbers
    # Hardware Adaption: [2,3,8,4,7,9,8,2,6,5,1,6,1,2,3,4] -> sorted [1,1,2,2,2,3,3,4,4,5,6,6,7,8,8,9]
    
    dut._log.info("Running Test Case 2")
    input_2_str = ['2','3','8','4','7','9','8','2','6','5','1','6','1','2','3','4']
    input_2 = [int(x) for x in input_2_str]
    
    set_input(input_2)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    result_2 = get_output()
    expected_2 = [1, 1, 2, 2, 2, 3, 3, 4, 4, 5, 6, 6, 7, 8, 8, 9]
    
    if result_2 != expected_2:
        raise TestFailure(f"Test 2 Failed: Got {result_2}, Expected {expected_2}")
    dut._log.info("Test 2 Passed")

    # --- Test Case 3 ---
    # Input: ['1','3','5','7','1', '3','13', '15', '17','5', '7 ','9','1', '11']
    # Hardware: [1,3,5,7,1,3,13,15,17,5,7,9,1,11,0,0]
    # Expected: [1,1,1,3,3,5,5,7,7,9,11,13,15,17,0,0]
    
    dut._log.info("Running Test Case 3")
    input_3_str = ['1','3','5','7','1', '3','13', '15', '17','5', '7 ','9','1', '11']
    # Pad to 16
    input_3 = [int(x) for x in input_3_str] + [0, 0]
    
    set_input(input_3)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    result_3 = get_output()
    expected_3 = [1,1,1,3,3,5,5,7,7,9,11,13,15,17,0,0]
    
    if result_3 != expected_3:
        raise TestFailure(f"Test 3 Failed: Got {result_3}, Expected {expected_3}")
    dut._log.info("Test 3 Passed")
    
    # Summary
    dut._log.info("All 3 adapted tests passed!")
