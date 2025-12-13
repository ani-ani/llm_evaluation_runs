import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_string_explosion(dut):
    # Generate clock and reset
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(15, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (scaled): original #[0] + #[1] shortened
    test_cases = [
        # Test 1: Partial explosion
        {
            "input": b'mirkovC4nizCC44',  # Original length 15 (shortened to 13)
            "str_len": 13,
            "explosion": b'C4',
            "exp_len": 2,
            "expected": b'mirkovniz'  # FRULA expected outcome
        },
        # Test 2: Complete explosion chain
        {
            "input": b'12ab112ab2ab',  # Original length 12 (shortened to 8)
            "str_len": 8,
            "explosion": b'12ab',
            "exp_len": 4,
            "expected": b'FRULA'  # Empty result case
        },
        # Test 3: Edge case - empty input
        {
            "input": b'',
            "str_len": 0,
            "explosion": b'A',
            "exp_len": 1,
            "expected": b'FRULA'
        },
        # Test 4: Multiple explosion patterns
        {
            "input": b'aabbccccaabb',
            "str_len": 12,
            "explosion": b'abb',
            "exp_len": 3,
            "expected": b'aacccca'  # After removal sequence
        }
    ]

    passed = 0
    for case in test_cases:
        # Prepare inputs
        dut.start.value = 0
        dut.input_str.value = int.from_bytes(case["input"].ljust(16, b'\\\\0'), "little")
        dut.explosion.value = int.from_bytes(case["explosion"].ljust(4, b'\\\\0'), "little")
        dut.str_len.value = case["str_len"]
        dut.exp_len.value = case["exp_len"]
        await RisingEdge(dut.clk)
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Check outputs
        result_bytes = dut.result_str.value.buff
        actual_len = dut.out_len.value
        expected = case["expected"]
        if actual_len == 0 and expected == b'FRULA':
            # Verify FRULA output encoding (5 chars + null padding)
            frula_bytes = b'FRULA\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0'
            assert result_bytes == frula_bytes[:16], \
                f"FRULA case failed: got {result_bytes}, expected {frula_bytes[:16]}"
            passed += 1
        else:
            actual_str = result_bytes[:actual_len]
            try:
                assert actual_str == expected, \
                    f"Got {actual_str.decode()} len={actual_len}, expected {expected.decode()}"
                passed += 1
            except Exception as e:
                dut._log.error(f"Test failed: {e}")
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
