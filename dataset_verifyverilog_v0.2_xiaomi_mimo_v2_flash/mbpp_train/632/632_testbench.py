import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_move_zero(dut):
    """Test move_zero module"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    for i in range(16):
        dut.input_array[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [1,0,2,0,3,4] -> [1,2,3,4,0,0]
    dut.num_elements.value = 6
    dut.input_array[0].value = 1
    dut.input_array[1].value = 0
    dut.input_array[2].value = 2
    dut.input_array[3].value = 0
    dut.input_array[4].value = 3
    dut.input_array[5].value = 4
    # Set rest to 0
    for i in range(6, 16):
        dut.input_array[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 50
    cycles = 0
    while dut.done.value == 0 and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    # Check output
    expected = [1,2,3,4,0,0]
    for i in range(6):
        if dut.output_array[i].value != expected[i]:
            raise TestFailure(f"Test 1: Index {i} expected {expected[i]}, got {dut.output_array[i].value}")
    
    print(f"Test 1 passed: {expected}")
    
    # Reset for next test
    await RisingEdge(dut.clk)
    
    # Test 2: [2,3,2,0,0,4,0,5,0] -> [2,3,2,4,5,0,0,0,0]
    dut.num_elements.value = 9
    dut.input_array[0].value = 2
    dut.input_array[1].value = 3
    dut.input_array[2].value = 2
    dut.input_array[3].value = 0
    dut.input_array[4].value = 0
    dut.input_array[5].value = 4
    dut.input_array[6].value = 0
    dut.input_array[7].value = 5
    dut.input_array[8].value = 0
    for i in range(9, 16):
        dut.input_array[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    cycles = 0
    while dut.done.value == 0 and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    expected = [2,3,2,4,5,0,0,0,0]
    for i in range(9):
        if dut.output_array[i].value != expected[i]:
            raise TestFailure(f"Test 2: Index {i} expected {expected[i]}, got {dut.output_array[i].value}")
    
    print(f"Test 2 passed: {expected}")
    
    # Reset for next test
    await RisingEdge(dut.clk)
    
    # Test 3: [0,1,0,1,1] -> [1,1,1,0,0]
    dut.num_elements.value = 5
    dut.input_array[0].value = 0
    dut.input_array[1].value = 1
    dut.input_array[2].value = 0
    dut.input_array[3].value = 1
    dut.input_array[4].value = 1
    for i in range(5, 16):
        dut.input_array[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    cycles = 0
    while dut.done.value == 0 and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    expected = [1,1,1,0,0]
    for i in range(5):
        if dut.output_array[i].value != expected[i]:
            raise TestFailure(f"Test 3: Index {i} expected {expected[i]}, got {dut.output_array[i].value}")
    
    print(f"Test 3 passed: {expected}")
    
    print("All 3 tests passed!")