import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_apple_collector(dut):
    """Test apple collector logic."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.p_write.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to load tree
    # Tree structure: node -> parent
    # We use the first example: N=3, parents: 1, 1
    # Node 2 -> 1, Node 3 -> 1
    # Root is 1 (depth 0). Nodes 2,3 are depth 1.
    # Parity: depth 0 has 1 node (odd), depth 1 has 2 nodes (even).
    # Total collected = 1 + 0 = 1.

    parents = {2: 1, 3: 1} # Map node -> parent

    dut._log.info("Loading parent array...")
    # Load parents into DUT
    # p_addr is 0-based for nodes 2..16
    for node, parent in parents.items():
        addr = node - 2
        dut.p_addr.value = addr
        dut.p_data.value = parent
        dut.p_write.value = 1
        await RisingEdge(dut.clk)
    dut.p_write.value = 0

    dut._log.info("Starting computation...")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1

    if timeout >= 500:
        raise TestFailure("Did not finish in time")

    # Check result
    result = int(dut.result.value)
    dut._log.info(f"Result: {result}")
    
    expected = 1
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")

    # Test Case 2: N=5, parents: 1, 2, 2, 2
    # Node 2->1, Node 3->2, Node 4->2, Node 5->2
    # Depth 0: {1} -> count 1 (odd)
    # Depth 1: {2} -> count 1 (odd)
    # Depth 2: {3, 4, 5} -> count 3 (odd)
    # Total = 1 + 1 + 1 = 3

    dut._log.info("Test Case 2: Loading parents...")
    parents2 = {2: 1, 3: 2, 4: 2, 5: 2}
    for node, parent in parents2.items():
        dut.p_addr.value = node - 2
        dut.p_data.value = parent
        dut.p_write.value = 1
        await RisingEdge(dut.clk)
    dut.p_write.value = 0

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1

    if timeout >= 500:
        raise TestFailure("Test 2: Did not finish in time")

    result = int(dut.result.value)
    expected = 3
    if result != expected:
        raise TestFailure(f"Test 2: Expected {expected}, got {result}")

    dut._log.info(f"All tests passed! Result: {result}")