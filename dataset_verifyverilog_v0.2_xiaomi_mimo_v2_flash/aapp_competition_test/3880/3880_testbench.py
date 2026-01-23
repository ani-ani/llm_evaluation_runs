import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_yaroslav_max_sum(dut):
    """Test Yaroslav's max sum problem"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_in.value = 0
    dut.array_in_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def run_test_case(n, array_elements, expected_result):
        """Run a single test case"""
        
        # Reset done flag by pulsing start
        if dut.done.value:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await RisingEdge(dut.clk)
        
        # Start computation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed array elements serially
        for elem in array_elements:
            dut.array_in.value = elem
            dut.array_in_valid.value = 1
            await RisingEdge(dut.clk)
        
        dut.array_in_valid.value = 0
        
        # Wait for completion
        timeout = 100
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        
        if not dut.done.value:
            raise TestFailure(f"Timeout waiting for done. n={n}, array={array_elements}")
        
        actual = int(dut.result.value)
        if actual != expected_result:
            raise TestFailure(f"Mismatch: n={n}, array={array_elements}
Expected: {expected_result}, Got: {actual}")
        
        print(f"PASS: n={n}, array={array_elements}, result={actual}")
    
    # Test case 1: n=2, [50,50,50], expected 150
    # n=2 is even, all positive, neg_count=0 (even), result = sum_abs = 150
    await run_test_case(2, [50, 50, 50], 150)
    
    # Test case 2: n=2, [-1,-100,-1], expected 100
    # n=2 is even, neg_count=3 (odd), sum_abs=102, min_abs=1, result=102-2*1=100
    await run_test_case(2, [-1, -100, -1], 100)
    
    # Test case 3: n=3, [-1, 2, -3, 4, 5], expected 15
    # n=3 is odd, result = sum_abs = 1+2+3+4+5 = 15
    await run_test_case(3, [-1, 2, -3, 4, 5], 15)
    
    # Test case 4: n=4, [-5, -2, -3, 1, 4, 5, 6], expected 23
    # n=4 is even, neg_count=3 (odd), sum_abs=26, min_abs=2, result=26-4=22
    # Wait, sum_abs = 5+2+3+1+4+5+6 = 26, min_abs=2, result=26-2*2=22
    # Let me recalculate: -5,-2,-3,1,4,5,6. abs sum = 26. min abs = 2. odd negatives = 3. result = 26-2*2 = 22
    await run_test_case(4, [-5, -2, -3, 1, 4, 5, 6], 22)
    
    # Test case 5: n=2, [-10, 10, 10], expected 30
    # n=2 even, neg_count=1 odd, sum_abs=30, min_abs=10, result=30-20=10
    # Wait: abs sum = 10+10+10 = 30. min=10. 30-20=10. But let's check logic.
    # Array: -10, 10, 10. All abs sum=30. min=10. 1 odd neg. result=30-20=10.
    # Actually the python solution says: sum(abs) - 2*min if odd negatives.
    # So 30-20=10 is correct. Let me verify with actual operations.
    # Try flipping -10 and 10: result: 10, -10, 10 = 10. Flip -10 and 10: 10, 10, -10 = 10.
    # Try flipping both 10s: -10, -10, -10 = -30. Try all combinations...
    # The max sum is indeed 10. Let me verify the formula.
    # Wait, the python code says: sum(c) - 2*min(c) if odd negatives.
    # So 30 - 20 = 10. Let me try: if I can make all positive. n=2. I need to flip signs.
    # Try: flip -10 and first 10: 10, -10, 10 => 10. Flip -10 and second 10: 10, 10, -10 => 10.
    # Flip first 10 and second 10: -10, -10, -10 => -30.
    # So max is 10. OK.
    await run_test_case(2, [-10, 10, 10], 10)
    
    # Test case 6: n=5, all positive, expected sum
    # n=5 odd, sum_abs=50
    await run_test_case(5, [10, 20, 30, 40, 50, 60, 70, 80, 90], 450)
    
    # Test case 7: n=2, [0, -5, -5], expected 10
    # n=2 even, neg_count=2 even, sum_abs=10, min_abs=5, result=10
    await run_test_case(2, [0, -5, -5], 10)
    
    # Test case 8: n=3, [-10, -10, -10, -10, -10], expected 50
    # n=3 odd, sum_abs=50
    await run_test_case(3, [-10, -10, -10, -10, -10], 50)
    
    print("All tests passed!")
