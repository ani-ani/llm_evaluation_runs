import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Grid helpers
def resize_grid(grid, max_n, max_m):
    resized = []
    for i in range(max_n):
        row = ''
        for j in range(max_m):
            if i < len(grid) and j < len(grid[i]):
                row += grid[i][j]
            else:
                row += '#'
        resized.append(row)
    return resized

def grid_to_flat(grid, max_n, max_m):
    flat = 0
    for i in range(max_n):
        for j in range(max_m):
            bit = 0 if grid[i][j] == '.' else 1
            flat |= (bit << (i * max_m + j))
    return flat

def parse_input(input_str):
    lines = input_str.strip().split('\n')
    n, m = map(int, lines[0].split())
    grid = [list(lines[i]) for i in range(1, n+1)]
    return n, m, grid

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_treasure_island(dut):
    MAX_N = 8
    MAX_M = 8
    CLK_PERIOD = 10

    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units='ns').start())
    await reset_dut(dut)

    test_cases = [
        ("2 2\n..\n..", 2, "2x2 empty"),
        ("4 4\n....\n#.#.\n....\n.#..", 1, "4x4 bottleneck"),
        ("3 4\n....\n.##.\n....", 2, "3x4 paths"),
        ("1 5\n.....", 1, "1x5 row"),
        ("5 1\n.\n.\n.\n.\n.", 1, "5x1 column"),
        ("1 3\n.#.", 0, "1x3 block"),
        ("6 1\n.\n.\n#\n.\n.\n.", 0, "6x1 block"),
        ("5 2\n..\n..\n..\n..\n#.", 1, "5x2 bottleneck"),
        ("4 3\n..#\n...\n..#\n#..", 1, "4x3 complex"),
        ("5 4\n...#\n....\n....\n###.\n....", 1, "5x4 obstacle"),
    ]

    passed = 0
    failed = 0

    for idx, (input_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {desc}")
        try:
            n, m, grid = parse_input(input_str)
            resized = resize_grid(grid, MAX_N, MAX_M)
            flat = grid_to_flat(resized, MAX_N, MAX_M)

            dut.n.value = n
            dut.m.value = m
            dut.grid_flat.value = flat

            await start_computation(dut)
            await wait_for_done(dut)

            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")

            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")

            cocotb.log.info(f"  PASS: {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1

    cocotb.log.info(f"Results: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")