import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_math_problem_solver(dut):
    """Test the math problem solver module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.m.value = 0
    dut.n.value = 0
    dut.p.value = 0
    dut.q.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: m=5, n=2, p=8, q=4 -> should find 20512
    dut.m.value = 5
    dut.n.value = 2
    dut.p.value = 8
    dut.q.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max ~1000 cycles for small search)
    timeout = 2000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value == 1:
        result = int(dut.result.value)
        print(f"Test 1: Found result = {result}")
        assert result == 20512, f"Expected 20512, got {result}"
    else:
        print("Test 1: No result found")
        assert False, "Should have found 20512"
    
    await RisingEdge(dut.clk)
    
    # Test case 2: m=2, n=1, p=11, q=4 -> should be IMPOSSIBLE
    dut.m.value = 2
    dut.n.value = 1
    dut.p.value = 11
    dut.q.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value == 0:
        print("Test 2: Correctly found IMPOSSIBLE")
    else:
        result = int(dut.result.value)
        print(f"Test 2: Incorrectly found {result}")
        assert False, "Should be IMPOSSIBLE"
    
    await RisingEdge(dut.clk)
    
    # Test case 3: Additional test - m=3, n=1, p=1, q=2
    # Should find: 102 (10 concatenated with 1 = 101, *2 = 202 != 102)
    # Let's try m=3, n=1, p=5, q=2
    # Find X such that X = (Y concatenated with 5) * 2
    # Y is first 2 digits of X
    # X = 125: Y=12, Y concat 5 = 125, 125*2 = 250 != 125
    # X = 150: Y=15, Y concat 5 = 155, 155*2 = 310 != 150
    # This is hard to guess, let's use known solvable
    # m=4, n=1, p=4, q=2
    # Try X=2400: Y=24, 24 concat 4 = 244, *2 = 488
    # Need systematic check
    
    # Let's use m=3, n=0, p=5, q=2  
    # X = (Y concat 5) * 2, Y = X (since n=0)
    # X = (X concat 5) * 2 is impossible
    # Try m=4, n=2, p=8, q=4 (similar to test 1 but smaller)
    # m=4, n=1, p=8, q=3
    # Check manually: m=4, n=1, p=8, q=2
    # X = (first 3 digits concat 8) * 2
    # Try X=1024: Y=102, 1028*2=2056
    # Try X=2056: Y=205, 2058*2=4116
    # Try X=4116: Y=411, 4118*2=8236
    # Try X=8236: Y=823, 8238*2=16476 (5 digits)
    
    # Let's try m=3, n=1, p=2, q=4
    # X = (first 2 digits concat 2) * 4
    # Try X=102: Y=10, 102*4=408
    # Try X=204: Y=20, 202*4=808
    # Try X=408: Y=40, 402*4=1608
    # None match
    
    # Test case 3: m=2, n=0, p=5, q=2 -> X = (X concat 5) * 2 (impossible)
    # Let's try m=3, n=2, p=5, q=2
    # X = (first 1 digit concat 5) * 2
    # Try X=105: Y=1, 15*2=30
    # Try X=305: Y=3, 35*2=70
    # Try X=505: Y=5, 55*2=110
    # Try X=705: Y=7, 75*2=150
    # Try X=905: Y=9, 95*2=190
    
    # Let's search for a small solvable case manually
    # m=2, n=1, p=2, q=5
    # X = (single digit concat 2) * 5
    # X=12: Y=1, 12*5=60
    # X=22: Y=2, 22*5=110
    # X=32: Y=3, 32*5=160
    # None work
    
    # Use m=1, n=0, p=2, q=1: X = (X concat 2) * 1 = X concat 2 (impossible)
    # m=1, n=1, p=2, q=3
    # X = (empty concat 2) * 3 = 2*3 = 6
    # But X must be 1-digit, Y is empty (0), Y concat 2 = 2, *3 = 6
    # X=6, Y=0 (first 1 digit of 6 is 6, not 0), wait n=1 means remove first 1 digit from 1-digit X
    # If m=n, then Y is empty, which means Y=0
    # So X = (0 concat p) * q = p * q
    # And X must be m-digit
    # Test: m=1, n=1, p=2, q=3
    # X = 2 * 3 = 6, which is 1-digit, Y is empty (0)
    # Check: Y=0, concat p=2 gives 2, *q=3 gives 6 = X. Correct!
    
    dut.m.value = 1
    dut.n.value = 1
    dut.p.value = 2
    dut.q.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value == 1:
        result = int(dut.result.value)
        print(f"Test 3: Found result = {result}")
        assert result == 6, f"Expected 6, got {result}"
    else:
        print("Test 3: No result found")
        assert False, "Should have found 6"
    
    await RisingEdge(dut.clk)
    
    # Test case 4: m=1, n=1, p=3, q=3 -> X = 3*3 = 9
    dut.m.value = 1
    dut.n.value = 1
    dut.p.value = 3
    dut.q.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value == 1:
        result = int(dut.result.value)
        print(f"Test 4: Found result = {result}")
        assert result == 9, f"Expected 9, got {result}"
    else:
        print("Test 4: No result found")
        assert False, "Should have found 9"
    
    await RisingEdge(dut.clk)
    
    # Test case 5: m=2, n=1, p=2, q=4
    # X = (single digit concat 2) * 4
    # Try digits 1-9: 12*4=48, 22*4=88, 32*4=128, 42*4=168, 52*4=208, 62*4=248, 72*4=288, 82*4=328, 92*4=368
    # None are 2-digit. So IMPOSSIBLE
    dut.m.value = 2
    dut.n.value = 1
    dut.p.value = 2
    dut.q.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value == 0:
        print("Test 5: Correctly found IMPOSSIBLE")
    else:
        result = int(dut.result.value)
        print(f"Test 5: Incorrectly found {result}")
        assert False, "Should be IMPOSSIBLE"
    
    print("All tests completed successfully!")
