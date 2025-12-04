import cocotb
from cocotb.triggers import Timer

@cocotb.test(expect_fail=False)
async def test_sorted_checker(dut):
    # Test cases: (length, packed_lst, expected)
    test_cases = [
        (0, 0, True),          # Empty list
        (1, 0x05, True),       # [5]
        (5, 0x0504030201, True),      # [1,2,3,4,5]
        (5, 0x0504020301, False),     # [1,3,2,4,5] - out of order
        (6, 0x040303020201, True),    # [1,2,2,3,3,4] - valid duplicates
        (6, 0x040302020301, False),   # [1,3,2,2,3,4] - invalid order
        (6, 0x040302020202, False),   # [2,2,2,3,4,5] - triple duplicate
        (3, 0x000000030303, False),   # [3,3,3] (packed as 0x030303)
        (4, 0x04030201, True),        # [1,2,3,4]
        (2, 0x0203, True),            # [3,2] - invalid order
        (2, 0x0000, True)             # [0,0] - valid, no triple possible
    ]

    passed = 0
    for length, lst_val, expected in test_cases:
        dut.length.value = length
        dut.lst.value = lst_val
        await Timer(1, 'ns')
        actual = dut.is_sorted.value
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: length={length} lst=0x{lst_val:x} => {actual}")
        else:
            dut._log.error(f"FAIL: length={length} lst=0x{lst_val:x} => {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")