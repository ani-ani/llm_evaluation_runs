import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_special_filter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (original adapted to 8-element arrays)
    test_cases = [
        ([5, -2, 1, -5, 0,0,0,0], 0),
        ([15, -73, 14, -15, 0,0,0,0], 1),
        ([33, -2, -3, 45, 21, 109, 0,0], 2),
        ([43, -12, 93, 125, 121, 109, 0,0], 4),
        ([71, -2, -33, 75, 21, 19, 0,0], 3),
        ([1,0,0,0,0,0,0,0], 0),
        ([0,0,0,0,0,0,0,0], 0)
    ]
    
    passed = 0
    
    for nums, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        for i, val in enumerate(nums):
            dut.nums[i].value = val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 16 cycles
        for _ in range(16):
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: {nums} -> {expected}")
        else:
            dut._log.error(f"FAIL: {nums} -> {dut.count.value}, expected {expected}")
        
        await Timer(10, units="ns")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")