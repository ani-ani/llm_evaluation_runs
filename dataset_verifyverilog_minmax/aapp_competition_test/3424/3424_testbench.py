import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time

@cocotb.test()
async def test_age_base(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Test cases: (y, l, expected_base)
    test_cases = [
        (32, 20, 16),   # Original sample (scaled)
        (400, 50, 44),  # Custom: 400 in base44 = '94'
        (100, 100, 10), # Base10 identity case
        (255, 255, 10), # Must use base10
        (15, 13, 12)    # 15 in base12 is '13' (1*12+3=15)
    ]
    
    passed = 0
    total = len(test_cases)
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for (y_val, l_val, expected) in test_cases:
        # Load inputs
        dut.y.value = y_val
        dut.l.value = l_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 10000 cycles)
        timeout = 10000
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        assert timeout > 0, "Test timed out"
        
        # Check result
        if dut.b.value == expected:
            passed += 1
            dut._log.info(f"PASS: y={y_val}, l={l_val} -> b={dut.b.value}")
        else:
            dut._log.error(f"FAIL: y={y_val}, l={l_val} -> got {dut.b.value}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total
