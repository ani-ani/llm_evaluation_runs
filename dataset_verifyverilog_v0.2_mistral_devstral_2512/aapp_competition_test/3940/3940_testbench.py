import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_array_specializer(dut):
    """Test the array specializer module."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.query_valid.value = 0
    dut.l_i.value = 0
    dut.r_i.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Queries result in min_length = 2
    # Queries: (1,3) -> len 3, (2,5) -> len 4, (4,5) -> len 2
    # Expected min_mex = 2
    queries = [(1, 3), (2, 5), (4, 5)]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed queries
    for q in queries:
        dut.query_valid.value = 1
        dut.l_i.value = q[0]
        dut.r_i.value = q[1]
        await RisingEdge(dut.clk)
    
    dut.query_valid.value = 0
    
    # Wait for processing
    # Expected: IDLE -> READ_QUERIES -> COMPUTE -> OUTPUT
    # We need to wait until done is high
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    # Check min_mex
    assert dut.min_mex.value == 2, f"Expected min_mex 2, got {dut.min_mex.value}"
    assert dut.output_valid.value == 1, "Output should be valid"
    
    # Check array output sequence (0, 1, 0, 1, 0, 1, 0, 1)
    expected_seq = [0, 1, 0, 1, 0, 1, 0, 1]
    
    dut._log.info("Starting array output check")
    for i in range(8):
        await RisingEdge(dut.clk)
        dut._log.info(f"Cycle {i}: Got {dut.array_out.value}, Expected {expected_seq[i]}")
        assert dut.array_out.value == expected_seq[i], f"Mismatch at index {i}"

    # Test Case 2: Queries result in min_length = 3
    # Queries: (0,3) -> len 4, (1,3) -> len 3
    # Expected min_mex = 3
    # Reset for second test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    queries_2 = [(0, 3), (1, 3)]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for q in queries_2:
        dut.query_valid.value = 1
        dut.l_i.value = q[0]
        dut.r_i.value = q[1]
        await RisingEdge(dut.clk)
    
    dut.query_valid.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.min_mex.value == 3, f"Expected min_mex 3, got {dut.min_mex.value}"
    
    # Expected sequence: 0, 1, 2, 0, 1, 2, 0, 1
    expected_seq_2 = [0, 1, 2, 0, 1, 2, 0, 1]
    for i in range(8):
        await RisingEdge(dut.clk)
        assert dut.array_out.value == expected_seq_2[i], f"Mismatch at index {i} for test 2"
