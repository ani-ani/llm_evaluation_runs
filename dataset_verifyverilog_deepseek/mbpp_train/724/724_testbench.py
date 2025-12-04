import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_power_digit_sum(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (2, 4, 7),   # 2^4=16 → 1+6=7
        (8, 3, 8),    # 8^3=512 → 5+1+2=8
        (8, 2, 10),   # 8^2=64 → 6+4=10
        (3, 3, 9),    # 3^3=27 → 2+7=9
        (15, 2, 9),   # 15^2=225 → 2+2+5=9
        (1, 5, 1)     # 1^5=1 → 1
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for base, power, expected in test_cases:
        dut.base.value = base
        dut.power.value = power
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 50 cycles)
        timeout = 50
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error(f"Timeout for base={base}, power={power}")
            continue
            
        if dut.digit_sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: {base}^{power} → sum={dut.digit_sum.value}")
        else:
            dut._log.error(f"FAIL: {base}^{power} → got {dut.digit_sum.value}, expected {expected}")
        
        await RisingEdge(dut.clk) # cycle between tests
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")