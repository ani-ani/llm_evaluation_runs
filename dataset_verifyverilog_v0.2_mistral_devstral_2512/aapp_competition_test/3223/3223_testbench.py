import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_forest_constructor(dut):
    # Clock generation (50% duty cycle)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.V.value = 0
    for i in range(8):
        dut.target_degree[i].value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to run a test case
    async def run_test(V, degrees, expected_possible, description):
        print(f"Running test: {description}")
        
        # Set inputs
        dut.V.value = V
        for i in range(8):
            if i < V:
                dut.target_degree[i].value = degrees[i]
            else:
                dut.target_degree[i].value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check results
        assert dut.done.value == 1, "Timeout: done not asserted"
        
        if expected_possible:
            assert dut.valid.value == 1, f"Test '{description}': Expected POSSIBLE but got IMPOSSIBLE"
            print(f"  PASS: Valid=1, Edges={dut.edge_count.value}")
            # Optional: Verify degree constraints (hard to do fully in testbench without graph library)
        else:
            assert dut.valid.value == 0, f"Test '{description}': Expected IMPOSSIBLE but got POSSIBLE"
            print(f"  PASS: Valid=0 (Correctly impossible)")
        
        await RisingEdge(dut.clk)

    # Test Case 1: Sample 1 -> 1 1 2 (POSSIBLE)
    # V=3, Degrees: 1, 1, 2. Sum=4, Max=2. Valid.
    # Expected edges: (1,3), (2,3) -> (0,2), (1,2) in 0-based
    await run_test(3, [1, 1, 2], True, "Sample 1: 1 1 2")

    # Test Case 2: Sample 2 -> 1 2 (IMPOSSIBLE)
    # V=2, Degrees: 1, 2. Sum=3 (odd). Invalid.
    await run_test(2, [1, 2], False, "Sample 2: 1 2")

    # Test Case 3: Sample 3 -> 2 2 2 (IMPOSSIBLE)
    # V=3, Degrees: 2, 2, 2. Sum=6. Max possible edges for 3 nodes is 2 (Tree). Sum > 2*(3-1)=4. Invalid.
    await run_test(3, [2, 2, 2], False, "Sample 3: 2 2 2")

    # Test Case 4: V=0 (POSSIBLE)
    await run_test(0, [], True, "V=0")

    # Test Case 5: V=1, Deg=0 (POSSIBLE)
    await run_test(1, [0], True, "V=1, Deg=0")

    # Test Case 6: V=1, Deg=1 (IMPOSSIBLE)
    await run_test(1, [1], False, "V=1, Deg=1")

    # Test Case 7: Path graph 3 nodes -> 1 1 0 (Wait, sum 2, max 1, 1, 0. Valid)
    # Actually 1 1 0 connects 1-2. Let's do 1 2 1 (Sum=4, Valid)
    # Nodes: 0,1,2. Degrees: 1,2,1.
    # Node 1 is center. Connect 0-1, 2-1. Edges: (0,1), (1,2).
    await run_test(3, [1, 2, 1], True, "Path 1-2-3 (1 2 1)")

    # Test Case 8: Disconnected trees -> 1 0 1 (Sum 2)
    # V=3. Degrees 1,0,1. Sum=2. Edges max 2. Valid.
    # This forms two trees (0 connected to nothing? Wait, degree 1 needs a partner). 
    # If sum is 2, we must have an edge. Since node 1 has degree 0, we have nodes 0 and 2 with degree 1.
    # They must connect to each other. Edge (0,2).
    await run_test(3, [1, 0, 1], True, "Two nodes connected (1 0 1)")

    # Test Case 9: Star graph 4 nodes -> 3 1 1 1 (Sum=6, Max=3, Valid)
    # Center node 0 connects to 1,2,3. Edges (0,1), (0,2), (0,3).
    await run_test(4, [3, 1, 1, 1], True, "Star 4 nodes")
