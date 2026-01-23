import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_slime_k_solver(dut):
    """Test Slime K Solver with multiple test cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    dut.a_0.value = 0
    dut.a_1.value = 0
    dut.a_2.value = 0
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Original Example 1 - no
    # n=5, k=3, A=[1,5,2,6,1]
    # k=3 not in array, should be no
    dut.k.value = 3
    dut.a_0.value = 1
    dut.a_1.value = 5
    dut.a_2.value = 2
    dut.a_3.value = 6
    dut.a_4.value = 1
    dut.a_5.value = 0  # unused
    dut.a_6.value = 0
    dut.a_7.value = 0
    
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
        raise TestFailure("Test Case 1: Module did not complete in time")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test Case 1 FAILED: Expected 0 (no), got {dut.result.value}")
    print("Test Case 1 PASSED: Correctly identified impossible case")
    
    await Timer(20, units='ns')
    
    # Test Case 2: Original Example 2 - yes
    # n=1, k=6, A=[6]
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.k.value = 6
    dut.a_0.value = 6
    dut.a_1.value = 0
    dut.a_2.value = 0
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test Case 2: Module did not complete")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test Case 2 FAILED: Expected 1 (yes), got {dut.result.value}")
    print("Test Case 2 PASSED: Single element case works")
    
    await Timer(20, units='ns')
    
    # Test Case 3: Original Example 3 - yes
    # n=3, k=2, A=[1,2,3]
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.k.value = 2
    dut.a_0.value = 1
    dut.a_1.value = 2
    dut.a_2.value = 3
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test Case 3: Module did not complete")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test Case 3 FAILED: Expected 1 (yes), got {dut.result.value}")
    print("Test Case 3 PASSED: Adjacent pair >= k works")
    
    await Timer(20, units='ns')
    
    # Test Case 4: Original Example 4 - no
    # n=4, k=3, A=[3,1,2,3]
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.k.value = 3
    dut.a_0.value = 3
    dut.a_1.value = 1
    dut.a_2.value = 2
    dut.a_3.value = 3
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test Case 4: Module did not complete")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test Case 4 FAILED: Expected 0 (no), got {dut.result.value}")
    print("Test Case 4 PASSED: Non-adjacent case correctly rejected")
    
    await Timer(20, units='ns')
    
    # Test Case 5: Original Example 5 - yes
    # n=10, k=3, A=[1,2,3,4,5,6,7,8,9,10]
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.k.value = 3
    dut.a_0.value = 1
    dut.a_1.value = 2
    dut.a_2.value = 3
    dut.a_3.value = 4
    dut.a_4.value = 5
    dut.a_5.value = 6
    dut.a_6.value = 7
    dut.a_7.value = 8
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test Case 5: Module did not complete")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test Case 5 FAILED: Expected 1 (yes), got {dut.result.value}")
    print("Test Case 5 PASSED: Large array with adjacent >= k works")
    
    print("
=== Summary: All 5 test cases passed! ===")