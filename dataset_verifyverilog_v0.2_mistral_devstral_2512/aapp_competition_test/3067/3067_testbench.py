import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_patience_merge(dut):
    """Test the patience merge module with sample inputs."""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N_in.value = 0
    for i in range(8):
        dut.L_seq[i].value = 0
        for j in range(8):
            dut.seq_data[i][j].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1
    # Input: 3 sequences
    # Seq 0: [2]
    # Seq 1: [100]
    # Seq 2: [1]
    # Expected Output: 1, 2, 100
    
    dut.N_in.value = 3
    dut.L_seq[0].value = 1
    dut.seq_data[0][0].value = 2
    dut.L_seq[1].value = 1
    dut.seq_data[1][0].value = 100
    dut.L_seq[2].value = 1
    dut.seq_data[2][0].value = 1

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    results = []
    # Wait for outputs. Total cards = 3
    for _ in range(3):
        # Wait for result_valid to be high
        while not dut.result_valid.value:
            await RisingEdge(dut.clk)
        results.append(int(dut.result_value.value))
        await RisingEdge(dut.clk)
        # result_valid usually stays high for 1 cycle or needs checking.
        # Our logic sets it high in OUTPUT, then low in CHECK_DONE.
        # So we captured it on the cycle it was high.
        
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Test 1 Results: {results}")
    assert results == [1, 2, 100], f"Expected [1, 2, 100], got {results}"

    # Test Case 2
    # Input: 2 sequences
    # Seq 0: [10, 20, 30, 40, 50]
    # Seq 1: [28, 27]
    # Expected Output: 10, 20, 28, 27, 30, 40, 50
    
    # Reset pointers by pulsing start again (or full reset, let's do reset for clarity)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.N_in.value = 2
    dut.L_seq[0].value = 5
    dut.seq_data[0][0].value = 10
    dut.seq_data[0][1].value = 20
    dut.seq_data[0][2].value = 30
    dut.seq_data[0][3].value = 40
    dut.seq_data[0][4].value = 50
    
    dut.L_seq[1].value = 2
    dut.seq_data[1][0].value = 28
    dut.seq_data[1][1].value = 27

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    results = []
    # Total cards = 7
    for _ in range(7):
        while not dut.result_valid.value:
            await RisingEdge(dut.clk)
        results.append(int(dut.result_value.value))
        await RisingEdge(dut.clk)
        
    while not dut.done.value:
        await RisingEdge(dut.clk)

    dut._log.info(f"Test 2 Results: {results}")
    assert results == [10, 20, 28, 27, 30, 40, 50], f"Expected [10, 20, 28, 27, 30, 40, 50], got {results}"

    # Test Case 3 (Tie-breaking / Lookahead)
    # Input: 2 sequences
    # Seq 0: [5, 1, 2]
    # Seq 1: [5, 1, 1]
    # Expected Output: 5, 1, 1, 5, 1, 2 (Wait, let's trace)
    # Start: [5, 1, 2] vs [5, 1, 1]. Heads equal 5. Lookahead: 1 vs 1. Lookahead: 2 vs 1. 1 < 2. So pick Seq 1.
    # Output 5 (Seq 1). Seq 1: [1, 1]. Seq 0: [5, 1, 2].
    # Heads: 1 vs 5. Pick 1.
    # Output 1 (Seq 1). Seq 1: [1]. Seq 0: [5, 1, 2].
    # Heads: 1 vs 5. Pick 1.
    # Output 1 (Seq 1). Seq 1: []. Seq 0: [5, 1, 2].
    # Heads: 5 vs nothing (infinity). Pick 5.
    # Output 5 (Seq 0). Seq 0: [1, 2].
    # Heads: 1 vs nothing. Pick 1.
    # Output 1 (Seq 0). Seq 0: [2].
    # Heads: 2 vs nothing. Pick 2.
    # Output 2 (Seq 0).
    # Expected: [5, 1, 1, 5, 1, 2]
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.N_in.value = 2
    dut.L_seq[0].value = 3
    dut.seq_data[0][0].value = 5
    dut.seq_data[0][1].value = 1
    dut.seq_data[0][2].value = 2
    
    dut.L_seq[1].value = 3
    dut.seq_data[1][0].value = 5
    dut.seq_data[1][1].value = 1
    dut.seq_data[1][2].value = 1

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    results = []
    # Total cards = 6
    for _ in range(6):
        while not dut.result_valid.value:
            await RisingEdge(dut.clk)
        results.append(int(dut.result_value.value))
        await RisingEdge(dut.clk)
        
    while not dut.done.value:
        await RisingEdge(dut.clk)

    dut._log.info(f"Test 3 Results: {results}")
    assert results == [5, 1, 1, 5, 1, 2], f"Expected [5, 1, 1, 5, 1, 2], got {results}"
    
    dut._log.info("All tests passed!")