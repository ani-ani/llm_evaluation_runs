import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_hill_number(dut):
    # Precomputed test cases (scaled to 10-bit inputs)
    test_cases = [
        (10, 10),     # Valid hill number
        (55, 55),     # Valid hill number
        (101, -1),    # Invalid (1>0 after peak)
        (123, -1),    # Invalid (1<2>3, then invalid)
        (1000, 715)   # Valid hill number with count
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for (input_val, expected) in test_cases:
        dut.num.value = input_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 4 cycles for processing
        for _ in range(4):
            await RisingEdge(dut.clk)
        
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Input {input_val}: Expected {expected}, got {dut.result.value}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)