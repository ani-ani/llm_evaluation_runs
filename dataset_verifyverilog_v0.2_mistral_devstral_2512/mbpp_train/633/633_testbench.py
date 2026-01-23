import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_pair_xor_sum(dut):
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [5,9,7,6], n=4, expected=47
    dut.arr[0].value = 5
    dut.arr[1].value = 9
    dut.arr[2].value = 7
    dut.arr[3].value = 6
    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    if dut.result.value != 47:
        raise TestFailure(f"Test 1: Expected 47, got {dut.result.value}")
    print("Test 1 passed: [5,9,7,6] sum=47")
    
    # Wait one more cycle before next test
    await RisingEdge(dut.clk)
    
    # Test 2: [7,3,5], n=3, expected=12
    dut.arr[0].value = 7
    dut.arr[1].value = 3
    dut.arr[2].value = 5
    dut.n.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    if dut.result.value != 12:
        raise TestFailure(f"Test 2: Expected 12, got {dut.result.value}")
    print("Test 2 passed: [7,3,5] sum=12")
    
    await RisingEdge(dut.clk)
    
    # Test 3: [7,3], n=2, expected=4
    dut.arr[0].value = 7
    dut.arr[1].value = 3
    dut.n.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    if dut.result.value != 4:
        raise TestFailure(f"Test 3: Expected 4, got {dut.result.value}")
    print("Test 3 passed: [7,3] sum=4")
    
    # Edge case: n=0
    await RisingEdge(dut.clk)
    dut.n.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Edge case: n=0 should finish in 2 cycles")
    if dut.result.value != 0:
        raise TestFailure(f"Edge case: n=0 expected 0, got {dut.result.value}")
    print("Edge case passed: n=0")
    
    # Edge case: n=1
    dut.arr[0].value = 42
    dut.n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Edge case: n=1 should finish in 2 cycles")
    if dut.result.value != 0:
        raise TestFailure(f"Edge case: n=1 expected 0, got {dut.result.value}")
    print("Edge case passed: n=1")
    
    print("All 5 tests passed!")