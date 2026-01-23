import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_multi_knapsack_dp(dut):
    """Test the multi_knapsack_dp module with a few jewels and k=5."""
    # Create a clock with a 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.jewel_size.value = 0
    dut.jewel_value.value = 0

    # Reset the DUT
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case adapted from Sample 1:
    # Original items: (2, 8), (1, 1), (3, 4), (5, 100)
    # Scaled for 8-bit: Keep as is (fits in 8 bits)
    # k is max 16, so we test up to k=9 (fits)
    # Expected output for k=1..9: 1 8 9 9 100 101 108 109 109
    
    # We will process 4 items sequentially.
    items = [
        (2, 8),
        (1, 1),
        (3, 4),
        (5, 100)
    ]

    # Feed items
    for size, val in items:
        dut.valid_in.value = 1
        dut.jewel_size.value = size
        dut.jewel_value.value = val
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        # Allow one cycle for internal processing if needed, or wait for state change
        # The module should handle valid_in pulse. We'll wait a bit.
        await RisingEdge(dut.clk) 

    # Start the output sequence
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Expected results for sizes 1 to 9
    expected = [1, 8, 9, 9, 100, 101, 108, 109, 109]
    
    received = []
    
    # Wait for result_valid and capture outputs
    # We expect up to 9 results (since we processed items for a knapsack that supports up to item 5 size, but the DP table is for k=16)
    # The problem says output k integers. We assume k=9 for this test case.
    # Let's assume the module knows k. In the prompt, I specified k=16 is max, but we need to output 1..k.
    # Let's verify for the first 9 values.
    
    # We need to wait for the output sequence to start.
    # In the design, we iterate current_size from 1 to k.
    # Let's count cycles where result_valid is high.
    
    count = 0
    while count < len(expected):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            received.append(int(dut.current_max_value.value))
            count += 1
    
    dut._log.info(f"Received: {received}")
    dut._log.info(f"Expected: {expected}")

    if received != expected:
        raise TestFailure(f"Mismatch! Received {received}, Expected {expected}")

    # Test Case 2: Sample 2
    # Items: (2, 2), (3, 8), (2, 7), (2, 4), (3, 8)
    # k=7. Expected: 0 7 8 11 15 16 19
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    items2 = [
        (2, 2),
        (3, 8),
        (2, 7),
        (2, 4),
        (3, 8)
    ]

    for size, val in items2:
        dut.valid_in.value = 1
        dut.jewel_size.value = size
        dut.jewel_value.value = val
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        await RisingEdge(dut.clk)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    expected2 = [0, 7, 8, 11, 15, 16, 19]
    received2 = []
    count = 0
    while count < len(expected2):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            received2.append(int(dut.current_max_value.value))
            count += 1

    dut._log.info(f"Received 2: {received2}")
    dut._log.info(f"Expected 2: {expected2}")

    if received2 != expected2:
        raise TestFailure(f"Mismatch Case 2! Received {received2}, Expected {expected2}")
