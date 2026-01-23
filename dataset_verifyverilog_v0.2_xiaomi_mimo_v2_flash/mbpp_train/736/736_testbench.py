import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_left_insertion(dut):
    """Test left insertion point finder using binary search"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.value.value = 0
    dut.array_size.value = 0
    for i in range(8):
        setattr(dut, f'array_data[{i}]', 0)
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [1,2,4,5], value=6, expect=4
    dut.array_size.value = 4
    dut.array_data[0].value = 1
    dut.array_data[1].value = 2
    dut.array_data[2].value = 4
    dut.array_data[3].value = 5
    dut.value.value = 6
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: done not asserted within timeout")
    if dut.result.value != 4:
        raise TestFailure(f"Test 1: Expected 4, got {dut.result.value}")
    print("Test 1 passed: [1,2,4,5], value=6 -> 4")
    
    await RisingEdge(dut.clk)
    
    # Test 2: [1,2,4,5], value=3, expect=2
    dut.array_data[0].value = 1
    dut.array_data[1].value = 2
    dut.array_data[2].value = 4
    dut.array_data[3].value = 5
    dut.value.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: done not asserted within timeout")
    if dut.result.value != 2:
        raise TestFailure(f"Test 2: Expected 2, got {dut.result.value}")
    print("Test 2 passed: [1,2,4,5], value=3 -> 2")
    
    await RisingEdge(dut.clk)
    
    # Test 3: [1,2,4,5], value=7, expect=4
    dut.array_data[0].value = 1
    dut.array_data[1].value = 2
    dut.array_data[2].value = 4
    dut.array_data[3].value = 5
    dut.value.value = 7
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: done not asserted within timeout")
    if dut.result.value != 4:
        raise TestFailure(f"Test 3: Expected 4, got {dut.result.value}")
    print("Test 3 passed: [1,2,4,5], value=7 -> 4")
    
    # Test 4: [1,3,5], value=2, expect=1
    dut.array_size.value = 3
    dut.array_data[0].value = 1
    dut.array_data[1].value = 3
    dut.array_data[2].value = 5
    dut.value.value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 4: done not asserted within timeout")
    if dut.result.value != 1:
        raise TestFailure(f"Test 4: Expected 1, got {dut.result.value}")
    print("Test 4 passed: [1,3,5], value=2 -> 1")
    
    # Test 5: [1,2,3], value=0, expect=0
    dut.array_size.value = 3
    dut.array_data[0].value = 1
    dut.array_data[1].value = 2
    dut.array_data[2].value = 3
    dut.value.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 5: done not asserted within timeout")
    if dut.result.value != 0:
        raise TestFailure(f"Test 5: Expected 0, got {dut.result.value}")
    print("Test 5 passed: [1,2,3], value=0 -> 0")
    
    print("
All tests passed!")