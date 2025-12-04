import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_substring(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Test cases (text, pattern, expected substring, start, end, match)
    test_cases = [
        # Test 1 (scaled)
        (b"python prog    ", b"python  ", b"python", 0, 5, 1),
        # Test 2 (scaled)
        (b"progprogming   ", b"prog    ", b"prog  ", 0, 3, 1),
        # Test 3 (no match)
        (b"cpp programming", b"python  ", b"", 0, 0, 0)
    ]

    passed = 0
    total = len(test_cases)

    for idx, (text, pattern, exp_sub, exp_start, exp_end, exp_match) in enumerate(test_cases):
        # Apply reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load test vectors
        dut.text_data.value = int.from_bytes(text, 'big')
        dut.pattern_data.value = int.from_bytes(pattern, 'big')
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        for _ in range(16):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)

        # Extract results
        result_bytes = dut.substring.value.value.to_bytes(8, 'big').rstrip()

        # Check results
        if (
            dut.match_found.value == exp_match
            and result_bytes == exp_sub
        ):
            if exp_match:
                if (
                    dut.start_pos.value == exp_start
                    and dut.end_pos.value == exp_end
                ):
                    passed += 1
                    dut._log.info(f"Test {idx+1} PASSED")
                else:
                    dut._log.error(f"Test {idx+1} FAILED: Got positions ({dut.start_pos.value},{dut.end_pos.value}) vs expected ({exp_start},{exp_end})")
            else:
                passed += 1
                dut._log.info(f"Test {idx+1} PASSED")
        else:
            dut._log.error(f"Test {idx+1} FAILED: Got match={dut.match_found.value} '{result_bytes.decode('ascii', 'replace')}' vs expected {exp_match} '{exp_sub.decode('ascii', 'replace')}'")

        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"{total-passed} tests failed"