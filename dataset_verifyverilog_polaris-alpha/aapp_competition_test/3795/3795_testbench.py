import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_currency(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases [n, d, e, expected]
    test_cases = [
        (100,  60, 70, 40),
        (410,  55, 70,  5),
        (600,  60, 70,  0),
        (50,   60, 70, 50),
        (420,  70, 65,  0),
        (1750, 45, 50,  0)
    ]
    
    passed = 0
    for n_val, d_val, e_val, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = n_val
        dut.d.value = d_val
        dut.e.value = e_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
            
        # Check result
        if dut.min_rubles.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n_val}, d={d_val}, e={e_val} => {dut.min_rubles.value}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
