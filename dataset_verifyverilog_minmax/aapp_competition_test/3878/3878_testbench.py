import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_min_clique(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # (n, m, edges, expected_steps, expected_guests)
        (5, 6, [(1,2),(1,3),(2,3),(2,5),(3,4),(4,5)], 2, [2,3]),
        (4, 4, [(1,2),(1,3),(1,4),(3,4)], 1, [1]),
        (2, 1, [(2,1)], 0, []),
        (3, 2, [(1,3),(2,3)], 1, [3])
    ]
    passed = 0
    for n_val, m_val, edges, exp_steps, exp_guests in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        # Load inputs
        dut.n.value = n_val
        dut.m.value = m_val
        # Load edges over m cycles
        for i in range(m_val):
            u, v = edges[i]
            dut.u_in.value = u-1  # Convert to 0-based
            dut.v_in.value = v-1
            dut.edge_valid.value = 1
            await RisingEdge(dut.clk)
        dut.edge_valid.value = 0
        # Trigger computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion
        timeout = 0
        while not dut.done.value and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1
        assert timeout < 500, "Simulation timed out"
        # Check results
        correct = True
        if dut.step_count.value != exp_steps:
            dut._log.error(f"Step count {dut.step_count.value} != expected {exp_steps}")
            correct = False
        for i in range(exp_steps):
            actual = dut.guest_steps[i].value + 1  # Convert to 1-based
            if actual != exp_guests[i]:
                dut._log.error(f"Step {i+1} guest {actual} != expected {exp_guests[i]}")
                correct = False
        if correct:
            passed += 1
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
