import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_explosion(dut):
    # Clock setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (1, 2, 2, 2, 0, 1, 1, 0.3333333333),
        (1, 1, 1, 1, 0, 1, 0, 0.5),
        (1, 1, 2, 2, 0, 2, 0, 0.25)
    ]
    
    passed = 0
    for n, m, d_val, h1, h2, o1, o2, expected in test_cases:
        # Apply test case
        dut.num_my_minions.value = n
        dut.num_opp_minions.value = m
        dut.my_health_1.value = h1
        dut.my_health_2.value = h2
        dut.opp_health_1.value = o1
        dut.opp_health_2.value = o2
        dut.d.value = d_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.prob.value.signed_integer / 2**16
        if abs(actual - expected) \u003c 0.0001:
            passed += 1
        else:
            dut._log.error(f"Test failed. Expected {expected}, got {actual}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)