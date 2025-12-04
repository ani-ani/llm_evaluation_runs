import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from fixedpoint import FixedPoint  # Assuming cocotb supports FixedPoint

@cocotb.test()
async def test_icar(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())
    # Test cases (scaled to Q32.16 fixed-point)
    test_cases = [
        # n=1 (no lights)
        (1, [], [], []),  # Output: sqrt(2000) ~44.721 in Q16.16
        # n=2, light @1km: t_i=50, g=45, r=45
        (2, [50], [45], [45]),  # Expected ~68.524
        # n=2, light @1km: t_i=25, g=45, r=45
        (2, [25], [45], [45])   # Expected ~63.246
    ]
    tolerance = 1e-6  # Relative error tolerance
    passed = 0
    dut.start.value = 0
    dut.n.value = 0
    # Initialize light arrays to 0
    for i in range(16):
        dut.t_i[i].value = 0
        dut.g_i[i].value = 0
        dut.r_i[i].value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for (n, t_list, g_list, r_list) in test_cases:
        # Setup inputs
        dut.start.value = 0
        dut.n.value = n
        for i in range(len(t_list)):
            dut.t_i[i].value = t_list[i]
            dut.g_i[i].value = g_list[i]
            dut.r_i[i].value = r_list[i]
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        # Convert result to float
        fp_val = FixedPoint(dut.total_time.value, signed=False, int_bits=16, frac_bits=16)
        actual_time = float(fp_val)
        # Calculate expected (test t=0 resets simulation)
        if n == 1:
            expected = (2000) ** 0.5
        elif n == 2:
            if t_list[0] == 50:  # Test case 2
                expected = 68.52419365
            else:  # Test case 3
                expected = 63.2455532
        # Validate result
        rel_error = abs(actual_time - expected) / expected
        if rel_error < tolerance:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n}, expected={expected}, got={actual_time}, rel_error={rel_error}")
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
