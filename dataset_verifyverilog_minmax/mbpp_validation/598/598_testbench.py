import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_armstrong(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (153, 1),
        (259, 0),
        (4458, 0),
        (9474, 1),  # 4-digit Armstrong
        (0, 1)      # Edge case (treated as 1-digit)
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for num, expected in test_cases:
        dut.start.value = 1
        dut.number.value = num
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {num} → {expected}")
        else:
            dut._log.error(f"FAIL: {num} → {dut.result.value}, expected {expected}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)