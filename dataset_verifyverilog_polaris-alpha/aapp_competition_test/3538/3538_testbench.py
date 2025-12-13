import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.utils import get_sim_time
import random

@cocotb.test()
async def test_frog_escape(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: All frogs escape (Original: 3 frogs in 19µm pit)
    test1_input = [
        (15, 5, 3),  
        (12, 4, 4),  
        (20, 10, 5)
    ]
    test1_expected = 3
    
    # Test case 2: Only 2 escape (Original: Frog1 leap reduced)
    test2_input = [
        (14, 5, 3),  
        (12, 4, 4),  
        (20, 10, 5)
    ]
    test2_expected = 2
    
    # Edge case: Single frog
    test3_input = [(10, 5, 3)]
    test3_expected = 1 if (10 > 19-3) else 0
    
    test_cases = [ (3, 19, test1_input, test1_expected),
                  (3, 19, test2_input, test2_expected),
                  (1, 19, test3_input, test3_expected) ]
    passed = 0
    
    for (n, depth, frogs, expected) in test_cases:
        # Load inputs
        dut.num_frogs.value = n
        dut.pit_depth.value = depth
        for i in range(8):
            if i < len(frogs):
                dut.l_data[i].value = frogs[i][0]
                dut.w_data[i].value = frogs[i][1]
                dut.h_data[i].value = frogs[i][2]
            else:
                dut.l_data[i].value = 0
                dut.w_data[i].value = 0
                dut.h_data[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 40 cycles)
        for _ in range(50):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify output
        if dut.escaped_count.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: Expected %d, Got %d" % (expected, dut.escaped_count.value))
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
    assert passed == len(test_cases)