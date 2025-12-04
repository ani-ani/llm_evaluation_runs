import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_even_nested(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (flattened format: [level, value])
    test_cases = [
        # Test 1: (4,5,(7,6,(2,4)),6,8)
        {
            'in': [(0,4),(0,5),(1,7),(1,6),(2,2),(2,4),(0,6),(0,8)],
            'expected': [(0,4),(1,6),(2,2),(2,4),(0,6),(0,8)]
        },
        # Test 2: (5,6,(8,7,(4,8)),7,9)
        {
            'in': [(0,5),(0,6),(1,8),(1,7),(2,4),(2,8),(0,7),(0,9)],
            'expected': [(0,6),(1,8),(2,4),(2,8)]
        },
        # Test 3: (5,6,(9,8,(4,6)),8,10)
        {
            'in': [(0,5),(0,6),(1,9),(1,8),(2,4),(2,6),(0,8),(0,10)],
            'expected': [(0,6),(1,8),(2,4),(2,6),(0,8),(0,10)]
        },
        # Edge case: empty tuple
        {
            'in': [],
            'expected': []
        }
    ]

    passed = 0
    dut.start.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    for case in test_cases:
        # Prepare input
        input_size = len(case['in'])
        dut.size_in.value = input_size
        for idx in range(16):
            if idx < input_size:
                level, val = case['in'][idx]
                dut.flat_tuple[idx].value = (level << 8) | val
            else:
                dut.flat_tuple[idx].value = 0xFF  // mark unused

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        // Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        // Verify output
        expected = case['expected']
        size_match = dut.size_out.value == len(expected)
        if not size_match:
            dut._log.error(f"Size mismatch: got {dut.size_out.value}, expected {len(expected)}")

        data_match = True
        for i in range(16):
            raw = dut.flat_out[i].value
            level = raw >> 8
            val = raw & 0xFF

            if i >= len(expected):
                if val != 0xFF:
                    data_match = False
                    dut._log.error(f"Element {i} should be empty (0xFF) but is {val}")
            else:
                exp_level, exp_val = expected[i]
                if level != exp_level or val != exp_val:
                    data_match = False
                    dut._log.error(f"Element {i}: got ({level},{val}), expected ({exp_level},{exp_val})")

        if size_match and data_match:
            dut._log.info(f"PASS: {case['in']} → {case['expected']}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {case['in']}")

        await ClockCycles(dut.clk, 2)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")