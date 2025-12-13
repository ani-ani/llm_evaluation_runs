import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_paren_grouper(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test case storage: (input_string, expected_groups)
    # Note: Spaces will be converted to 0x20
    test_cases = [
        ('( ) (( )) (( )( ))', [
            (0, 1),    # '()'
            (3, 6),    # '(())'
            (8, 13)    # '(()())'
        ]),
        ('()(())', [
            (0, 1),    # '()'
            (2, 5)     # '(())'
        ]),
        ('((())))', []),  # Invalid
        ('', []),
        ('   ', [])
    ]

    await reset()
    passed = 0

    for input_str, expected in test_cases:
        # Format test input
        dut.start.value = 0
        char_arr = [0x20]*16  # Initialize with spaces

        # Convert string to ASCII values
        for i, c in enumerate(input_str[:16]):
            char_arr[i] = ord(c)

        # Load character array
        for i in range(16):
            dut.char_array[i].value = char_arr[i]

        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for processing (max 16 cycles)
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1

        # Validate outputs
        valid = True

        if dut.group_count.value != len(expected):
            valid = False
        else:
            for i in range(dut.group_count.value):
                s = dut.group_start[i].value
                e = dut.group_end[i].value
                if (s, e) != expected[i]:
                    valid = False

        if valid:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' -> {expected}")
        else:
            groups = [(dut.group_start[i].value, dut.group_end[i].value) for i in range(group_count)]
            dut._log.error(f"FAIL: '{input_str}'
  Expected: {expected}
  Got: {groups} with count={dut.group_count.value}")

        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)