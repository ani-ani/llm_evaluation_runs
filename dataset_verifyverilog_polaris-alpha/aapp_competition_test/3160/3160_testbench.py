import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
from fixed_point_models import fixed_point_to_decimal

@cocotb.test()
async def test_coin_flip(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        ("HH", 2.0),
        ("H?", 1.5),
        ("??", 1.5)
    ]

    passed = 0
    for seq, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1

        # Convert string to data/mask (4-bit version with padding)
        data = 0
        mask = 0
        pad_length = 4 - len(seq)
        for i, c in enumerate(seq + 'T'*pad_length):
            if i >= 4: break  # Limit to 4 bits
            if c == 'H':
                data |= 1 << (3-i)
            elif c == 'T':
                data &= ~(1 << (3-i))
            elif c == '?':
                mask |= 1 << (3-i)

        # Set inputs
        dut.data.value = data >> 2  # Our DUT handles 2-bit inputs
        dut.mask.value = mask >> 2  # Mask also 2-bit
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        await ClockCycles(dut.clk, 40)
        assert dut.done.value == 1, "Done signal not asserted"

        # Verify result
        fp_result = dut.result.value
        decimal_val = fixed_point_to_decimal(fp_result, 16, 16)

        if abs(decimal_val - expected) < 1e-6:
            passed += 1
        else:
            dut._log.error(f"Failed: {seq} => {decimal_val}, expected {expected}")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")