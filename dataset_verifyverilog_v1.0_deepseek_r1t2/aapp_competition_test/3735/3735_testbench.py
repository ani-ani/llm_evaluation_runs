import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_digit_sum_opt(dut):
    test_cases = [
        (35, 17),
        (10000000000, 91),
        (4394826, 90),
        (96, 24),
        (9999991, 109),
        (999999999992, 200),
        (290687942106, 153),
        (1000000000000, 109),
        (1, 1),
        (8, 8),
        (15, 15),
        (894, 39),
        (8581, 49),
        (41764, 58),
        (333625, 67),
        (13350712, 85),
        (142098087, 111),
        (4536444302, 116),
        (30892252868, 143),
        (990, 36),
        (9994, 58),
        (99993, 75),
        (999997, 97),
        (99999995, 131),
        (999999990, 144),
        (9999999998, 170),
        (99999999997, 187),
        (99, 18),
        (29, 11),
        (10, 10),
        (99999999999, 99),
        (19, 10),
        (109, 19),
        (39, 12),
        (999999, 54),
        (9999, 36),
        (199, 19),
        (1999, 28),
        (20, 11),
        (9111119, 68),
        (999, 27),
        (678186539, 116),
        (9999999, 63),
        (119, 20),
        (39999, 39),
        (408, 30),
        (909, 27),
        (1009, 28),
        (11, 11),
        (9, 9),
        (5, 5),
        (2999, 29),
        (324278748889, 160),
        (234799, 61),
        (110, 20),
        (110884501982, 146),
        (7019, 35),
        (17219, 47),
        (999999999999, 108),
        (849925977, 132),
        (700000019, 80),
        (190420131558, 138),
        (18, 18),
        (15901772, 95),
        (2303910749, 110),
        (2452148459, 116),
        (1140, 33),
        (155690477371, 154)
    ]

    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(10, units='ns')
        if is_value_defined(dut.result.value):
            result = int(dut.result.value)
        else:
            result = 0
        if result != expected:
            raise TestFailure(f"For n={n_val}, expected {expected}, got {result}")