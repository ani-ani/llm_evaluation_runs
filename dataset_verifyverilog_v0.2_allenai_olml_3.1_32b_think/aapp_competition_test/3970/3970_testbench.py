import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_k_mfree_subset(dut):
    """Test the k-multiple free subset module"""
    
    # Create a clock with a period of 10ns
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the system
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Example from problem (6 2: 2 3 6 5 4 10 -> result 3)
    # Sorted: 2, 3, 4, 5, 6, 10
    # Pairs: (2,4), (3,6), (5,10) -> pick one from each -> 3
    dut.k.value = 2
    dut.n.value = 6
    dut.arr[0].value = 2
    dut.arr[1].value = 3
    dut.arr[2].value = 6
    dut.arr[3].value = 5
    dut.arr[4].value = 4
    dut.arr[5].value = 10
    # Fill rest with 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal (max 300 cycles)
    cycles = 0
    while dut.done.value == 0 and cycles < 350:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.done.value != 1:
        raise TestFailure(f"Done signal not asserted after {cycles} cycles")
        
    if dut.result.value != 3:
        raise TestFailure(f"Test Case 1 Failed: Expected 3, Got {dut.result.value}")
    print("Test Case 1 Passed")
    
    await RisingEdge(dut.clk)
    
    # Test Case 2: k=1, distinct elements -> result = n
    # Input: 1 2 3
    dut.k.value = 1
    dut.n.value = 3
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 0
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 350:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.result.value != 3:
        raise TestFailure(f"Test Case 2 Failed: Expected 3, Got {dut.result.value}")
    print("Test Case 2 Passed")
    
    await RisingEdge(dut.clk)
    
    # Test Case 3: k=4, input 1 4 16 -> result 2 (can pick 1,16 or 4)
    # Sorted: 1, 4, 16
    # 1*4=4 present. If pick 1, skip 4. 4*4=16 present. If pick 4, skip 16. 
    # Wait, optimal is picking 1 and 16? No, 1*4=4, so if we pick 1, we exclude 4. 
    # But we can still pick 16 (16/4=4, but 4 was excluded, so 16 is valid relative to chosen set?).
    # Wait, the rule is: no pair x,y in the chosen set with y = x*k.
    # If we pick {1, 16}, is there a pair? 16 = 4*4, but 4 is not in set. 16 = 1*16 (k=4, so 16!=1*4).
    # So {1, 16} is valid. Size 2.
    # If we pick {4}, size 1.
    # So expected result is 2.
    dut.k.value = 4
    dut.n.value = 3
    dut.arr[0].value = 1
    dut.arr[1].value = 4
    dut.arr[2].value = 16
    dut.arr[3].value = 0
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 350:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.result.value != 2:
        raise TestFailure(f"Test Case 3 Failed: Expected 2, Got {dut.result.value}")
    print("Test Case 3 Passed")
    
    await RisingEdge(dut.clk)
    
    # Test Case 4: No multiples, all unique
    # Input: 2 3 5 7 (k=2)
    # Result: 4
    dut.k.value = 2
    dut.n.value = 4
    dut.arr[0].value = 2
    dut.arr[1].value = 3
    dut.arr[2].value = 5
    dut.arr[3].value = 7
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 350:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.result.value != 4:
        raise TestFailure(f"Test Case 4 Failed: Expected 4, Got {dut.result.value}")
    print("Test Case 4 Passed")
    
    await RisingEdge(dut.clk)
    
    # Test Case 5: Max size, chain of multiples k=2
    # Input: 1, 2, 4, 8, 16, 32, 64, 128
    # Result: 4 (Pick odds: 1, 4, 16, 64 OR evens: 2, 8, 32, 128)
    dut.k.value = 2
    dut.n.value = 8
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 4
    dut.arr[3].value = 8
    dut.arr[4].value = 16
    dut.arr[5].value = 32
    dut.arr[6].value = 64
    dut.arr[7].value = 128
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 350:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.result.value != 4:
        raise TestFailure(f"Test Case 5 Failed: Expected 4, Got {dut.result.value}")
    print("Test Case 5 Passed")
    
    print(f"All tests passed!")
