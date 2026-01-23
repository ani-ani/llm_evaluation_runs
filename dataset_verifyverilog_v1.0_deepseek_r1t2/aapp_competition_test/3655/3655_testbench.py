import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_compute_scores(dut):
    test_cases = [
        ("2 2\n1 0\n0 1\n3 3\n1 0 0\n0 1 0\n0 0 1\n", ["0 0", "1 1"]),
        ("2 2\n1 0\n0 1\n3 3\n0 0 0\n0 1 0\n0 0 1\n", ["1 1"]),
    ]

    for i, (input_str, expected) in enumerate(test_cases):
        lines = input_str.strip().split('\n')
        idx = 0
        W1, H1 = map(int, lines[idx].split()); idx += 1
        robot_image = []
        for _ in range(H1):
            robot_image.append(list(map(int, lines[idx].split()))); idx += 1
        W2, H2 = map(int, lines[idx].split()); idx += 1
        floor_image = []
        for _ in range(H2):
            floor_image.append(list(map(int, lines[idx].split()))); idx += 1

        robot_flat = 0
        for i in range(H1):
            for j in range(W1):
                robot_flat |= (robot_image[i][j] << (i*W1 + j))

        floor_flat = 0
        for i in range(H2):
            for j in range(W2):
                floor_flat |= (floor_image[i][j] << (i*W2 + j))

        dut.robot_flat.value = robot_flat
        dut.floor_flat.value = floor_flat

        await Timer(10, units='ns')

        score0 = int(dut.score0.value)
        score1 = int(dut.score1.value)
        score2 = int(dut.score2.value)
        score3 = int(dut.score3.value)

        scores = [score0, score1, score2, score3]
        max_score = max(scores)
        positions = [(0,0), (0,1), (1,0), (1,1)]
        actual = []
        for idx, (x,y) in enumerate(positions):
            if scores[idx] == max_score:
                actual.append(f"{x} {y}")

        if actual != expected:
            raise TestFailure(f"Test {i}: expected {expected}, got {actual}")
