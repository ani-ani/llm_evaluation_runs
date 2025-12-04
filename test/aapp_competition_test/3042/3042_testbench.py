import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from math import gcd

@cocotb.test()
async def test_lcm_tree(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz clock
    cocotb.start_soon(clock.start())
    
    test_cases = [
        # (n, node_values, expected_output)
        (7, [2,3,4,4,8,12,24], 2),
        (3, [7,7,7], 3),
        (5, [1,2,3,2,1], 0)
    ]
    
    # Initialize with reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for (n, vals, expected) in test_cases:
        
        # Pad input to 16 nodes with zeros (unused)
        padded = vals + [0]*(16 - len(vals))
        for i in range(16):
            dut.node_values[i].value = padded[i]
        dut.num_nodes.value = n
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 100 cycles)
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        # Check result
        actual = dut.result.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d, vals=%s" % (n, str(vals)))
            dut._log.error("  Expected: %d, Got: %d" % (expected, actual))
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))