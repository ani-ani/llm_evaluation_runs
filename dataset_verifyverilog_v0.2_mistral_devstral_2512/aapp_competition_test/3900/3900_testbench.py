import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_suspect_selection(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper function to pack inputs
    def pack_inputs(x_list, y_list):
        # Pack 3-bit values into 24-bit input (for max 8 coders)
        x_packed = 0
        y_packed = 0
        for i, (x, y) in enumerate(zip(x_list, y_list)):
            x_packed |= (x << (3 * i))
            y_packed |= (y << (3 * i))
        return x_packed, y_packed

    # Test Case 1: Example 1
    # n=4, p=2
    # Pairs: (2,3), (1,4), (1,4), (2,1) (1-indexed)
    # Converted to 0-indexed: (1,2), (0,3), (0,3), (1,0)
    # We need to map values 1-4 to 0-3?
    # Wait, the problem says suspects are coders 1 to n.
    # If n=4, suspects are 1,2,3,4.  
    # Inputs are indices of named coders. 
    # If input is 2 3, it means coder suspects 2 and 3.
    # In 0-indexed logic (Verilog internal), we need to handle values 1 to n.
    # Let's adjust the module or testbench to handle 1-based input and map to 0-based internal.
    # Actually, let's just pass 1-based values and compare them directly.
    
    # Re-packing for 1-based values 1..4 (3 bits enough)
    x_vals = [1, 0, 0, 1] # 2, 1, 1, 2 -> 2, 1, 1, 2 in 1-based
    y_vals = [2, 3, 3, 0] # 3, 4, 4, 1 -> 3, 4, 4, 1 in 1-based
    # Correct mapping: 
    # Input 2 3 -> x=2, y=3
    # Input 1 4 -> x=1, y=4
    # Input 1 4 -> x=1, y=4
    # Input 2 1 -> x=2, y=1
    
    x_list = [2, 1, 1, 2]
    y_list = [3, 4, 4, 1]
    
    x_packed, y_packed = pack_inputs(x_list, y_list)
    
    dut.n.value = 4
    dut.p.value = 2
    dut.x_arr.value = x_packed
    dut.y_arr.value = y_packed
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 20 cycles for small n=4)
    for _ in range(50):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Did not finish")
        
    expected = 6
    if int(dut.result.value) != expected:
        raise TestFailure(f"Test 1 failed: got {int(dut.result.value)}, expected {expected}")
    print(f"Test 1 passed: result={int(dut.result.value)}")

    # Test Case 2: Example 2
    # n=8, p=6
    # We will use a simplified version or subset if n=8 is too big for manual packing in python?
    # Module supports up to 8 coders (3 bits each).
    # Values are 1..8. 3 bits can hold 0-7. 
    # Wait, 1..8 needs 4 bits. Or we need to map 1..8 to 0..7.
    # Let's map inputs 1..n to 0..n-1 in the testbench before packing.
    
    # Input lines for Test 2:
    # 5 6 -> 4, 5
    # 5 7 -> 4, 6
    # 5 8 -> 4, 7
    # 6 2 -> 5, 1
    # 2 1 -> 1, 0
    # 7 3 -> 6, 2
    # 1 3 -> 0, 2
    # 1 4 -> 0, 3
    
    x_list_2 = [4, 4, 4, 5, 1, 6, 0, 0]
    y_list_2 = [5, 6, 7, 1, 0, 2, 2, 3]
    x_packed_2, y_packed_2 = pack_inputs(x_list_2, y_list_2)
    
    # Reset
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 8
    dut.p.value = 6
    dut.x_arr.value = x_packed_2
    dut.y_arr.value = y_packed_2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
        
    if dut.done.value != 1:
        raise TestFailure("Test 2: Did not finish")
        
    expected_2 = 1
    if int(dut.result.value) != expected_2:
        raise TestFailure(f"Test 2 failed: got {int(dut.result.value)}, expected {expected_2}")
    print(f"Test 2 passed: result={int(dut.result.value)}")

    # Test Case 3: Small case to verify edge logic
    # n=3, p=2
    # 2 3 -> 1, 2
    # 3 1 -> 2, 0
    # 2 1 -> 1, 0
    # Pairs: (1,2), (2,0), (1,0)
    # Check all 3 pairs.
    x_list_3 = [1, 2, 1]
    y_list_3 = [2, 0, 0]
    x_packed_3, y_packed_3 = pack_inputs(x_list_3, y_list_3)
    
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 3
    dut.p.value = 2
    dut.x_arr.value = x_packed_3
    dut.y_arr.value = y_packed_3
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    expected_3 = 3
    if int(dut.result.value) != expected_3:
        raise TestFailure(f"Test 3 failed: got {int(dut.result.value)}, expected {expected_3}")
    print(f"Test 3 passed: result={int(dut.result.value)}")

    # Test Case 4: n=4, p=1 (should be total pairs)
    # 3 2 -> 2, 1
    # 4 1 -> 3, 0
    # 4 2 -> 3, 1
    # 1 2 -> 0, 1
    # Total pairs for n=4 is 6.
    x_list_4 = [2, 3, 3, 0]
    y_list_4 = [1, 0, 1, 1]
    x_packed_4, y_packed_4 = pack_inputs(x_list_4, y_list_4)
    
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 4
    dut.p.value = 1
    dut.x_arr.value = x_packed_4
    dut.y_arr.value = y_packed_4
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
        
    expected_4 = 6
    if int(dut.result.value) != expected_4:
        raise TestFailure(f"Test 4 failed: got {int(dut.result.value)}, expected {expected_4}")
    print(f"Test 4 passed: result={int(dut.result.value)}")

    print(f"All tests passed!")
