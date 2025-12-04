import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_names(dut):
    # Clock generator
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (padded to 8 chars with null bytes)
    test_cases = [
        # Test 1 (original: ['Dylan', 'Diana', 'Joanne'] - 5+5+6=16)
        ([
            b'Dylan\\x00\\x00\\x00',   # Valid (5)
            b'Diana\\x00\\x00\\x00',   # Valid (5)
            b'Joanne\\x00\\x00',      # Valid (6)
            b'keith\\x00\\x00\\x00'    # Invalid
        ], 16),
        # Test 2 (original: ["Python", "Java"] - 6+4=10)
        ([
            b'php\\x00\\x00\\x00\\x00\\x00',   # Invalid
            b'res\\x00\\x00\\x00\\x00\\x00',    # Invalid
            b'Python\\x00\\x00',      # Valid (6)
            b'Java\\x00\\x00\\x00\\x00'       # Valid (4)
        ], 10),
        # Test 3 (original: ["Python", "aba"] but "aba" invalid → 6)
        ([
            b'abcd\\x00\\x00\\x00\\x00',   # Invalid
            b'Python\\x00\\x00',      # Valid (6)
            b'abba\\x00\\x00\\x00\\x00',    # Invalid
            b'aba\\x00\\x00\\x00\\x00\\x00'     # Invalid
        ], 6)
    ]

    passed = 0
    for idx, (names, expected) in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load names
        for i in range(4):
            name_bytes = names[i]
            name_array = getattr(dut, f'name{i+1}')
            for j in range(8):
                name_array[j].value = name_bytes[j]

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait 4 cycles for completion
        await ClockCycles(dut.clk, 4)

        # Check result
        if dut.total_length.value == expected:
            passed += 1
            dut._log.info(f"Test {idx+1} PASS: {dut.total_length.value} == {expected}")
        else:
            dut._log.error(f"Test {idx+1} FAIL: Got {dut.total_length.value}, expected {expected}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")