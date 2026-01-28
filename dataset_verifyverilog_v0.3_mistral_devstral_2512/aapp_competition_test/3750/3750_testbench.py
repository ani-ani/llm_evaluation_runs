import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_table_tennis(dut):
    test_cases = [
        (11, 11, 5, 1),
        (11, 2, 3, -1),
        (1, 5, 9, 14),
        (2, 3, 3, 2),
        (1, 1000000000, 1000000000, 2000000000),
        (2, 3, 5, 3),
        (1000000000, 1000000000, 1000000000, 2),
        (1, 0, 1, 1),
        (101, 99, 97, -1),
        (1000000000, 0, 1, -1),
        (137, 137, 136, 1),
        (255, 255, 255, 2),
        (1, 0, 1000000000, 1000000000),
        (123, 456, 789, 9),
        (666666, 6666666, 666665, -1),
        (1000000000, 999999999, 999999999, -1),
        (100000000, 100000001, 99999999, -1),
        (3, 2, 1000000000, -1),
        (999999999, 1000000000, 999999998, -1),
        (12938621, 192872393, 102739134, 21),
        (666666666, 1230983, 666666666, 1),
        (123456789, 123456789, 123456787, 1),
        (5, 6, 0, -1),
        (11, 0, 12, -1),
        (2, 11, 0, -1),
        (2, 1, 0, -1),
        (10, 11, 12, 2),
        (11, 12, 5, -1),
        (11, 12, 3, -1),
        (11, 15, 4, -1),
        (2, 3, 1, -1),
        (11, 12, 0, -1),
        (11, 13, 2, -1),
        (11, 23, 22, 4),
        (10, 21, 0, -1),
        (11, 23, 1, -1),
        (11, 10, 12, -1),
        (11, 1, 12, -1),
        (11, 5, 12, -1),
        (11, 8, 12, -1),
        (11, 12, 1, -1),
        (5, 4, 6, -1),
        (10, 1, 22, -1),
        (2, 3, 0, -1),
        (11, 23, 2, -1),
        (2, 1000000000, 1000000000, 1000000000),
        (11, 0, 15, -1),
        (11, 5, 0, -1),
        (11, 5, 15, -1),
        (10, 0, 13, -1),
        (4, 7, 0, -1),
        (10, 2, 8, -1),
        (11, 5, 22, -1),
        (11, 13, 0, -1),
        (2, 0, 3, -1),
        (10, 10, 0, -1),
        (10, 11, 10, 2),
        (3, 5, 4, 2),
        (11, 22, 3, -1)
    ]

    for i, (k_val, a_val, b_val, expected) in enumerate(test_cases):
        dut.k.value = k_val
        dut.a.value = a_val
        dut.b.value = b_val

        await Timer(100, units='ns')

        if not is_value_defined(dut.result.value):
            raise TestFailure(f'Test {i}: Result is undefined')

        result = int(dut.result.value)
        result = to_signed(result, 32)

        if result != expected:
            raise TestFailure(f'Test {i}: k={k_val}, a={a_val}, b={b_val}: expected {expected}, got {result}')

    dut._log.info('All tests passed')