import cocotb\\
from cocotb.triggers import RisingEdge, Timer\\
from cocotb.clock import Clock\\
\\
@cocotb.test()\\
async def test_ginger(dut):\\
    # Clock generator\\
    clock = Clock(dut.clk, 10, units='ns')\\
    cocotb.start_soon(clock.start())\\\
\\
    # Test cases (scaled down)\\
    test_cases = [\\
        (\\
            # Test case 1 (possible cycle)\\
            3, 3, 5, # n_nodes, n_roads, alpha\\
            [(0,1,100), (1,2,200), (2,0,300)], # edges (u,v,c)\\
            300**2 + 5*3 # (max_c^2 + alpha*K)\\
        ),\\
        (\\
            # Test case 2 (broken circuit)\\
            4, 3, 7, \\
            [(0,1,50), (1,2,100), (2,3,150)], # no cycle\\
            None # 'Poor girl'\\
        ),\\
        (\\
            # Test case 3 (multiple cycles)\\
            4, 5, 10, \\
            [(0,1,200), (1,2,150), (2,0,300), (1,3,250), (3,2,400)],\\
            min(400**2 + 10*5, 300**2 + 10*3) # multiple valid cycles\\
        )\\
    ]\\
\\
    passed = 0\\
    total = len(test_cases)\\
\\
    for i, (n, m, a, edges, expected) in enumerate(test_cases):\\
        # Reset\\
        dut.rst_n.value = 0\\
        dut.start.value = 0\\
        await RisingEdge(dut.clk)\\
        dut.rst_n.value = 1\\
        await RisingEdge(dut.clk)\\
\\
        # Write road data\\
        for j in range(m):\\
            dut.u_in.value = edges[j][0]\\
            dut.v_in.value = edges[j][1]\\
            dut.c_in.value = edges[j][2]\\
            dut.road_data_valid.value = 1 << j\\
            await RisingEdge(dut.clk)\\
        dut.road_data_valid.value = 0\\
\\
        # Set params and start\\
        dut.n_nodes.value = n\\
        dut.n_roads.value = m\\
        dut.alpha.value = a\\
        dut.start.value = 1\\
        await RisingEdge(dut.clk)\\
        dut.start.value = 0\\
\\
        # Wait for completion (1024 cycles)\\
        for _ in range(1024):\\
            await RisingEdge(dut.clk)\\\
\\
        # Check results\\
        if expected is None:\\
            assert dut.no_route.value == 1, f"Test {i} should have no route"\\
            if dut.no_route.value == 1:\\
                passed += 1\\
        else:\\
            assert dut.no_route.value == 0, f"Test {i} should have found a route"\\
            assert dut.min_energy.value == expected, (\\
                f"Test {i} failed: Got {dut.min_energy.value}, expected {expected}"\\
            )\\
            if dut.min_energy.value == expected:\\
                passed += 1\\
\\
        dut._log.info(f"Test case {i} completed")\\
\\
    dut._log.info(f"{passed}/{total} tests passed")