import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_page_operations(dut):
    # Test cases scaled to 8-bit constraints
    test_cases = [
        # (n, m, k, [p_items], expected_ops)
        (10, 4, 5, [3, 5, 7, 10], 3),
        (13, 4, 5, [7, 8, 9, 10], 1),
        (3, 2, 1, [1, 2], 2),
        (10, 5, 5, [2,3,4,5,6], 2),
        (16, 7, 5, [2,3,4,5,6,15,16], 3)
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    for n, m, k, p_items, expected in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.p_valid.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load special items
        for item in p_items:
            dut.p_data.value = item
            dut.p_valid.value = 1
            await RisingEdge(dut.clk)
        dut.p_valid.value = 0
        
        # Set parameters and start
        dut.n.value = n
        dut.m.value = m
        dut.k.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation to complete
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.out_op.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Input {n},{m},{k},{p_items} got {dut.out_op.value}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)