import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_z_checker(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Helper function to pack strings
    def pack_str(s):
        padded = s.ljust(8)[:8]
        return int.from_bytes(padded.encode('ascii'), 'little')

    test_cases = [
        ("pythonza", 1),   # Orig: "pythonzabc." - trimmed
        ("zxyabc  ", 0),   # Orig: "zxyabc." - padded
        ("lang  . ", 0),   # Orig: "  lang  ." - trimmed/padded
        ("buzzword", 1),  # Additional: 'z' in middle
        ("zone	xz ", 0)  # Additional: 'z' at start
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for s, expected in test_cases:
        dut.start.value = 1
        dut.char_pack.value = pack_str(s)
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait 8 cycles for processing
        for _ in range(8):
            await RisingEdge(dut.clk)

        assert dut.done.value == 1, "Done signal not set"
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{s}' -> {expected}")
        else:
            dut._log.error(f"FAIL: '{s}' -> {dut.result.value}, expected {expected}")
        await RisingEdge(dut.clk)
        assert dut.done.value == 0, "Done signal not cleared"

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")