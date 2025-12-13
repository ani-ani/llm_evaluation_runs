import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_directed_strong_connect(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Test 1: 3-node triangle (should be possible)
        (0b_0110_1000_1000_0000, 1, 0b_0010_0000_1000_0100),
        # Test 2: 4-node star (impossible)
        (0b_0001_0001_0001_1110, 0, 0),
        # Test 3: 4-node connected graph
        (0b_0101_1011_0100_1100, 1, 0b_0001_0011_0000_1000)
    ]
    
    passed = 0
    for i, (matrix_in, exp_possible, exp_graph) in enumerate(test_cases):
        dut.adj_matrix.value = matrix_in
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        try:
            assert dut.possible.value == exp_possible, f"Test {i+1}: Possible mismatch"
            if exp_possible:
                assert dut.directed_graph.value == exp_graph, f"Test {i+1}: Direction mismatch"
            passed += 1
        except AssertionError as e:
            dut._log.error(str(e))
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
