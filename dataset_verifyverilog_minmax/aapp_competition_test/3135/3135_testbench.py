import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_converter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (input, expected output)
    # Original: 10000 -> +0000 (padded to 8 bits)
    # Note: Output representation: 00='+', 01='-', 10='0'
    test_cases = [
        ("00010000", "0000000000000000"),  # +0000 -> 00 00 00 00
        ("00001111", "0000000000010001"),  # +000- -> 00 00 00 01 (last symbol = '-', others '+')
        ("00010111", "0000000100100001")   # ++00- -> 00 00 10 10 00 01 (first symbols) truncated
    ]

    # Reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for bin_str, expected in test_cases:
        # Prepare input
        bin_val = int(bin_str, 2)
        dut.bin_in.value = bin_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for processing (8 cycles)
        await ClockCycles(dut.clk, 8)

        # Check done signal
        if dut.done.value != 1:
            dut._log.error("Done not asserted after 8 cycles")

        # Compare output
        result = dut.signed_out.value.binstr
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Input {bin_str}: Expected {expected}, got {result}")

        # Wait 1 cycle before next test
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")