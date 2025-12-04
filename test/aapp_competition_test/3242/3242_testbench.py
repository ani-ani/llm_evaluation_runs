import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_min_energy(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    def fp_convert(f):
        return int(f * (1 << 20))
    
    test_cases = [
        (0.5, [2,1,0,0,0,0,0,0], [0.5,0.5,0,0,0,0,0,0], 1),
        (0.5, [2,1,0,0,0,0,0,0], [0.51,0.49,0,0,0,0,0,0], 2),
        (1.0, [2,5,0,0,0,0,0,0], [0.3291,0.6709,0,0,0,0,0,0], 7)
    ]
    
    passed = 0
    for p_val, energies, probs, expected in test_cases:
        dut.start.value = 0
        dut.rst_n.value = 0
        dut.p_target.value = fp_convert(p_val)
        
        for i in range(8):
            dut.energies[i].value = energies[i]
            dut.probs[i].value = fp_convert(probs[i])
        
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await ClockCycles(dut.clk, 257)
        
        if dut.done.value == 1:
            if int(dut.min_energy.value) == expected:
                passed += 1
            else:
                dut._log.error("Test failed: Expected %d, Got %d" % (expected, int(dut.min_energy.value)))
        else:
            dut._log.error("Done signal not asserted")
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))