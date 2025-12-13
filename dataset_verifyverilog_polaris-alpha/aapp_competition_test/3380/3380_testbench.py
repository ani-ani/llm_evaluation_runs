import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_road_prob(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (2, 1.0),   # Q16.16: 0x00010000
        (4, 0.962962962963)  # Q16.16: ~0x63161
    ]
    passed = 0
    
    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for (n_val, expected_float) in test_cases:
        # Q16.16 conversion
        expected_int = int(expected_float * (1 << 16))
        
        # Start calculation
        dut.N.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 3 cycles for result
        await ClockCycles(dut.clk, 3)
        
        # Verify output
        if dut.probability.value == expected_int:
            passed += 1
        else:
            hw_val = float(dut.probability.value) / (1 << 16)
            dut._log.error(
                f"Test failed: N={n_val}"
                f" HW:{hw_val:.12f} ({int(dut.probability.value):08x})"
                f" EXP:{expected_float:.12f}"
            )
        
        await RisingEdge(dut.clk)
        assert dut.done.value == 1, "Done not asserted"
        await RisingEdge(dut.clk)
        assert dut.done.value == 0, "Done should drop"
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"