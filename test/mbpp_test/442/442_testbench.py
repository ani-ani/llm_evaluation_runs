import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_positive_ratio(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Q8.8 conversion helper
    def to_fixed(x):
        return int(round(x * 256))
    
    # Test cases (scaled to max 16 elements)
    test_cases = [
        ([0,1,2,-1,-5,6,0,-3,-2,3,4,6,8], 13, 7/13), # Original: 0.54
        ([2,1,2,-1,-5,6,4,-3,-2,3,4,6,8], 13, 9/13), # Original: 0.69
        ([2,4,-6,-9,11,-12,14,-5,17], 9, 5/9),       # Original: 0.56
        ([], 0, 0),                                  # Edge case: empty
        ([5]*16, 16, 1.0),                           # All positive
    ]
    
    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for nums, size, expected in test_cases:
        # Zero-pad array to 16 elements
        padded = list(nums) + [0]*(16 - len(nums))
        
        # Load inputs
        dut.array_size.value = size
        for i in range(16):
            dut.nums[i].value = padded[i] 
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        expected_fixed = to_fixed(expected) 
        actual = dut.ratio.value.integer 
            
        if actual == expected_fixed or (size == 0 and actual == 0):
            passed += 1
            dut._log.info(f"PASS: {nums} -> {actual} ({expected:.2f})")
        else:
            actual_float = actual/256.0
            dut._log.error(f"FAIL: {nums} -> {actual_float:.2f} ({hex(actual)}), expected {expected:.2f} ({hex(expected_fixed)})")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)