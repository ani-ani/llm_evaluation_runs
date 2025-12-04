import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_gwen(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    test_cases = [
        (1, 0b01_01_01_01),
        (16, 0b11_11_11_11),
        (22, 0b100_11_100_10)
    ]
    passed = 0
    
    for (k_val, expected) in test_cases:
        dut.k.value = k_val
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')
        
        if dut.sequence.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: k={k_val} got {dut.sequence.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")