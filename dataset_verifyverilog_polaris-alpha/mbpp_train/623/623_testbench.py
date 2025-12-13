import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_power_list(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases adapted for 8 elements
    test_cases = [
        (2, [1,2,3,4,5,6,7,8], [1,4,9,16,25,36,49,64]),
        (3, [10,20,30,0,0,0,0,0], [1000,8000,27000,0,0,0,0,0]),
        (5, [12,15,0,0,0,0,0,0], [248832,759375,0,0,0,0,0,0]),
        (0, [5,10,15,20,25,30,35,40], [1,1,1,1,1,1,1,1]),
        (1, [256,257,258,259,260,261,262,263], [256,257,258,259,260,261,262,263])
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, nums_vec, expected_vec in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        
        # Load inputs
        dut.start.value = 0
        for i in range(8):
            dut.nums[i].value = nums_vec[i] if i < len(nums_vec) else 0
        dut.n.value = n
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        cycles = max(1, n)
        for _ in range(cycles):
            await RisingEdge(dut.clk)
        
        # Check results
        success = True
        for i in range(8):
            actual = dut.results[i].value.integer
            expected = expected_vec[i] if i < len(expected_vec) else 0
            if actual != expected:
                success = False
                dut._log.error(f"Element {i}: {nums_vec[i]}^{n}={actual}, expected {expected}")
        
        if success:
            passed += 1
            dut._log.info(f"Passed test case: exponent={n}")
        else:
            dut._log.error(f"Failed test case: exponent={n}")
        
    dut._log.info(f"{passed}/{total} test cases passed")
    assert passed == total