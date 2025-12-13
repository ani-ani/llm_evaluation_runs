import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_pokemon_gcd(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (n, [strengths], expected)
    test_cases = [
        (3, [2,3,4,0,0,0,0,0], 2),  # Example 1
        (5, [2,3,4,6,7,0,0,0], 3),  # Example 2
        (5, [1,1,1,1,1,0,0,0], 1),  # All 1's case
        (3, [3,6,9,0,0,0,0,0], 3),  # Same divisor
        (8, [2,4,6,8,10,12,14,16], 8),  # All divisible by 2
        (2, [13,26,0,0,0,0,0,0], 2)   # Large prime
    ]
    
    passed = 0
    for tc in test_cases:
        # Apply inputs
        dut.n.value = tc[0]
        dut.s0.value = tc[1][0]; dut.s1.value = tc[1][1]
        dut.s2.value = tc[1][2]; dut.s3.value = tc[1][3]
        dut.s4.value = tc[1][4]; dut.s5.value = tc[1][5]
        dut.s6.value = tc[1][6]; dut.s7.value = tc[1][7]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 25 cycles for processing
        for _ in range(25):
            await RisingEdge(dut.clk)
        
        # Verify outputs
        assert dut.done.value == 1, "Done not asserted"
        if dut.max_count.value == tc[2]:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d, strs=%s. Got %d, expected %d" % (tc[0], str(tc[1]), dut.max_count.value, tc[2]))
    
    # Final report
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
    assert passed == len(test_cases)