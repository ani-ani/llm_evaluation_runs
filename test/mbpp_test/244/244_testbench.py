import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math
def gold(N):
    x = int(math.isqrt(N)) + 1
    return x*x

@cocotb.test()
async def test_nps(dut):
    # Define test cases (include max 16-bit case)
    test_cases = [6, 9, 35, 0, 255, 65535]
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_cases)
    
    for N_val in test_cases:
        # Apply input
        dut.N.value = N_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 18 cycles)
        cycles_waited = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            cycles_waited += 1
            if cycles_waited > 25:
                assert False, "Timed out waiting for done signal"
        
        # Verify result
        expected = gold(N_val)
        actual = dut.result.value.integer
        
        try:
            assert actual == expected, f"For N={N_val}: Got {actual}, expected {expected}"
            passed += 1
            dut._log.info(f"PASS: N={N_val} => {actual}")
        except AssertionError as e:
            dut._log.error(str(e))
    
    dut._log.info(f"{passed}/{total} tests passed")