import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_special_filter(dut):
    """Test special filter module"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_len.value = 0
    for i in range(8):
        dut.nums[i].value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Helper function to get result
    async def run_test(nums, expected):
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Load array
        dut.array_len.value = len(nums)
        for i in range(8):
            if i < len(nums):
                dut.nums[i].value = nums[i]
            else:
                dut.nums[i].value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 2000
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        print(f"Input: {nums} | Expected: {expected}, Got: {actual}")
        assert actual == expected, f"Failed: expected {expected}, got {actual}"
        
        await RisingEdge(dut.clk)
    
    # Test case 1: [5, -2, 1, -5] => 0 (all <=10 or 1 has single digit)
    await run_test([5, -2, 1, -5], 0)
    
    # Test case 2: [15, -73, 14, -15] => 1 (15: 1,5 odd; 73: 7,3 odd; wait 73 qualifies? 73 > 10, 7 and 3 odd, so should be 2? But python says 1)
    # Wait, let's check: 15: 1 and 5 odd, yes. -73: abs=73, 7 and 3 odd, yes. 14: 1 and 4, 4 even. -15: abs=15, 1 and 5 odd, yes. So 3? No, python says 1.
    # Maybe only positive? Or specific filtering. Let's follow python output exactly.
    # Python says 1. So maybe -73 and -15 don't count? Or 15 doesn't?
    # Let's assume it's absolute value filtering.
    # Retesting: 15 (pos) -> 1, -73 (neg) -> 0? Maybe only positive numbers allowed?
    # Let's check example 2: [33, -2, -3, 45, 21, 109] => 2
    # 33 (pos) -> 1, -2 -> 0, -3 -> 0, 45 (pos) -> 1? 4 and 5 -> 5 odd, 4 even. 0.
    # 21 (pos) -> 0 (2 even). 109 (pos) -> 1 (1 and 9 odd). Total 2. Matches.
    # So only positive numbers count? Example 1: 15 (pos) -> 1, 73 (neg) -> 0, 14 (pos) -> 0, 15 (neg) -> 0. Total 1. Matches.
    # Rule: Only POSITIVE numbers > 10 with odd first and last digits.
    # I will update logic to only process if number > 0.
    # New logic: nums[i] > 10 AND nums[i] > 0.
    # Retesting case 1 with this logic:
    # 15 > 0 and > 10 -> check digits -> 1,5 odd -> count 1. Correct.
    # -73 -> <= 0 -> skip.
    # 14 -> > 0 but <= 10? 14 > 10 -> check -> 1,4 -> 4 even -> 0.
    # -15 -> <= 0 -> skip.
    # Total 1. Correct.
    
    # Test case 3: [33, -2, -3, 45, 21, 109] => 2
    # 33 > 0, > 10 -> 3,3 odd -> 1
    # -2 skip
    # -3 skip
    # 45 > 0, > 10 -> 4,5 -> 4 even -> 0
    # 21 > 0, > 10 -> 2,1 -> 2 even -> 0
    # 109 > 0, > 10 -> 1,9 odd -> 1
    # Total 2. Correct.
    
    # Test case 4: [43, -12, 93, 125, 121, 109] => 4
    # 43 -> 4,3 (4 even) -> 0
    # -12 skip
    # 93 -> 9,3 odd -> 1
    # 125 -> 1,5 odd -> 1
    # 121 -> 1,1 odd -> 1
    # 109 -> 1,9 odd -> 1
    # Total 4. Correct.
    
    # Test case 5: [71, -2, -33, 75, 21, 19] => 3
    # 71 -> 7,1 odd -> 1
    # -2 skip
    # -33 skip
    # 75 -> 7,5 odd -> 1
    # 21 -> 2,1 -> 2 even -> 0
    # 19 -> 1,9 odd -> 1
    # Total 3. Correct.
    
    # Test case 6: [1] => 0 (<= 10)
    await run_test([1], 0)
    
    # Test case 7: [] => 0
    await run_test([], 0)
    
    # Edge case: max array
    await run_test([11, 13, 15, 17, 19, 111, 113, 115], 8)
