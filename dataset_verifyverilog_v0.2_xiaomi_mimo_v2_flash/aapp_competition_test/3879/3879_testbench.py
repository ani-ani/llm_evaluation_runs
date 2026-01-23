import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_jackpot_checker(dut):
    """Test the jackpot checker logic"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_inputs.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("Starting tests...")
    
    # Test Case 1: Yes (75, 150, 75, 50 -> core is 25)
    # 75=3*5^2, 150=2*3*5^2, 50=2*5^2. Cores are all 25.
    dut.start.value = 1
    dut.num_inputs.value = 4
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs = [75, 150, 75, 50]
    for val in inputs:
        dut.data_valid.value = 1
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    # Wait for completion (approx 100 cycles for 4 inputs)
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 1, f"Expected Yes (1), got {dut.result.value}"
    print("Test 1 Passed: 75, 150, 75, 50 -> Yes")
    
    # Wait for idle
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 2: No (100, 150, 250)
    # 100=2^2*5^2 (core 25), 150=2*3*5^2 (core 25), 250=2*5^3 (core 50). Cores differ.
    dut.start.value = 1
    dut.num_inputs.value = 3
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs = [100, 150, 250]
    for val in inputs:
        dut.data_valid.value = 1
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 0, f"Expected No (0), got {dut.result.value}"
    print("Test 2 Passed: 100, 150, 250 -> No")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 3: Yes (1, 1, 1)
    dut.start.value = 1
    dut.num_inputs.value = 3
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs = [1, 1, 1]
    for val in inputs:
        dut.data_valid.value = 1
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.result.value == 1, f"Expected Yes (1), got {dut.result.value}"
    print("Test 3 Passed: 1, 1, 1 -> Yes")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 4: Yes (34, 34, 68, 34, 34, 68, 34) -> cores are 17
    dut.start.value = 1
    dut.num_inputs.value = 7
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs = [34, 34, 68, 34, 34, 68, 34]
    for val in inputs:
        dut.data_valid.value = 1
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.result.value == 1, f"Expected Yes (1), got {dut.result.value}"
    print("Test 4 Passed: 34... -> Yes")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 5: No (2, 3, 5, 7) -> Prime numbers, all different
    dut.start.value = 1
    dut.num_inputs.value = 4
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs = [2, 3, 5, 7]
    for val in inputs:
        dut.data_valid.value = 1
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.result.value == 0, f"Expected No (0), got {dut.result.value}"
    print("Test 5 Passed: 2, 3, 5, 7 -> No")
    
    print("All tests passed!")