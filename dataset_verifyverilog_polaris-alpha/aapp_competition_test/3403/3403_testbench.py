import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_query_steps(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (words padded to 8 chars with underscores)
    test_cases = [
        ("robi____", 12),  // Original sample
        ("hobi____", 10),
        ("hobit___", 16),
        ("rakija__", 7),  // Different ending
        ("hobotnic", 9)   // Exact first match
    ]

    passed = 0
    for query, expected in test_cases:
        # Convert to ASCII hex
        query_bytes = bytes(query, "ascii")
        query_val = int.from_bytes(query_bytes, "big")

        # Apply inputs
        dut.query_word.value = query_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if dut.step_count.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: Query={query} Steps={dut.step_count.value} Expected={expected}")
        await RisingEdge(dut.clk)  # Extra cycle

    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} passed")