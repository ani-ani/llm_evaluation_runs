import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_max_product(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Adapted test cases (original scaled for 8-bit inputs)
    test_cases = [
        ([3, 100, 4, 5, 150, 6, 0, 0], 3000),   # Original: [3,100,4,5,150,6] → 3*4*5*150=3000
        ([4, 42, 55, 68, 80, 0, 0, 0], 4*42*55*68),  # Scaled from original, product=4*42*55*68=628320
        ([10, 22, 9, 33, 21, 50, 41, 60], 2460),   # Original test case already fits
        ([5, 4, 3, 2, 1, 0, 0, 0], 5),          # All decreasing → max is first element
        ([10, 11, 12, 13, 14, 15, 16, 17], 10*11*12*13*14*15*16*17)  # Max possible product
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for arr, expected in test_cases:
        dut.start.value = 0
        # Load array
        for i in range(8):
            dut.arr[i].value = arr[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.max_product.value == expected:
            passed += 1
            dut._log.info(f"PASS: {arr} → {dut.max_product.value}")
        else:
            dut._log.error(f"FAIL: {arr} → {dut.max_product.value}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)