import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_odd_power_sum(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    
    # Test cases array (input n, expected output)
    test_cases = [
        (0, 0),
        (1, 1),
        (2, 82),
        (3, 707),
        (4, 3108)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for (test_n, expected) in test_cases:
        # Apply inputs
        dut.start.value = 1
        dut.n.value = test_n
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation (n cycles + 2 for latency)
        await ClockCycles(dut.clk, test_n + 2)
        
        # Check result
        if int(dut.done.value) == 1 and dut.sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: n={test_n} => sum={int(dut.sum.value)}")
        else:
            dut._log.error(f"FAIL: n={test_n} got sum={int(dut.sum.value)}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await ClockCycles(dut.clk, 2)
        
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total