import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_rescale(dut):
    # Q16.16 conversions
    def float_to_q16(x):
        return int(x * 65536)
    def q16_to_float(x):
        return x / 65536.0

    # Test cases (padded to 8 elements with zeros)
    test_cases = [
        ([2.0, 49.9], [0.0, 1.0]),
        ([100.0, 49.9], [1.0, 0.0]),
        ([1.0, 2.0, 3.0, 4.0, 5.0], [0.0, 0.25, 0.5, 0.75, 1.0]),
        ([12.0, 11.0, 15.0, 13.0, 14.0], [0.25, 0.0, 1.0, 0.5, 0.75])
    ]

    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    passed = 0

    for inputs, expected_outputs in test_cases:
        # Pad inputs
        padded_inputs = [float_to_q16(x) for x in inputs] + [0]*(8-len(inputs))

        # Apply inputs and reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for i in range(8):
            dut.numbers[i].value = padded_inputs[i]
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (15 cycles)
        for _ in range(15):
            await RisingEdge(dut.clk)

        # Check results
        errors = []
        for i in range(len(expected_outputs)):
            actual = q16_to_float(dut.result[i].value.integer)
            expected = expected_outputs[i]
            if abs(actual - expected) > 0.001:  # Allow 0.1% error
                errors.append(f"Element {i}: got {actual:.4f}, expected {expected}")

        if not errors:
            passed += 1
            dut._log.info(f"PASS: {inputs} → {expected_outputs}")
        else:
            for err in errors:
                dut._log.error(err)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)