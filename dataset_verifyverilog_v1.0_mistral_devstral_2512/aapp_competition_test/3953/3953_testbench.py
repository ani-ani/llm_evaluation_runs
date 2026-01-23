import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 16
DATA_WIDTH = 1
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_purification(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)

    test_cases = [
        (3, [".E.", "E.E", ".E."], [(1,1), (2,2), (3,1)]),
        (3, ["EEE", "E..", "E.E"], None),
        (5, ["EE.EE", "E.EE.", "E...E", ".EE.E", "EE.EE"], [(1,3), (2,2), (3,2), (4,1), (5,3)]),
        (3, ["EEE", "EEE", "..."], [(3,1), (3,2), (3,3)]),
        (3, [".EE", ".EE", ".EE"], [(1,1), (2,1), (3,1)]),
        (5, ["EE.EE", "EE..E", "EEE..", "EE..E", "EE.EE"], [(1,3), (2,3), (3,4), (4,3), (5,3)]),
        (1, ["E"], None),
        (2, ["EE", "EE"], None),
        (2, [".E", ".E"], [(1,1), (2,1)]),
        (3, [".EE", "EEE", "EEE"], None),
        (3, ["...", "EEE", "..E"], [(1,1), (1,2), (1,3)]),
        (4, ["E...", "E.EE", "EEEE", "EEEE"], None),
        (4, ["....", "E..E", "EEE.", ".EE."], None),
        (3, ["E..", "EEE", "E.."], [(1,1), (3,1)]),
        (4, ["EEEE", "..E.", "..E.", "..E."], [(2,1), (3,1), (4,1)]),
        (3, ["..E", ".EE", ".EE"], None),
        (6, [".EEEE", ".EEEE", "......", "......", "......", "EEEEEE"], [(1,1), (2,1), (3,1), (4,1), (5,1), (6,1)]),
        (3, ["EEE", "..E", "..."], [(2,1), (2,2), (3,1)])
    ]

    for test_idx, (n, grid, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: n={n}")
        n_actual = min(n, MAX_N)
        grid_actual = [row[:n_actual] for row in grid[:n_actual]]

        if has_signal(dut, 'n'):
            dut.n.value = n_actual
        else:
            raise TestFailure("Signal 'n' not found")

        for i in range(n_actual):
            for j in range(n_actual):
                dut.grid[i][j] = 1 if grid_actual[i][j] == 'E' else 0
        for i in range(n_actual, MAX_N):
            for j in range(MAX_N):
                dut.grid[i][j] = 0

        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        cycles = 0
        outputs = []
        done = False
        no_solution = False

        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1

            if has_signal(dut, 'output_valid') and is_value_defined(dut.output_valid.value) and int(dut.output_valid.value) == 1:
                row = int(dut.row_out.value)
                col = int(dut.col_out.value)
                outputs.append((row, col))
                cocotb.log.info(f"Output: row={row}, col={col}")

            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                if has_signal(dut, 'no_solution') and is_value_defined(dut.no_solution.value) and int(dut.no_solution.value) == 1:
                    no_solution = True
                break

        if not done:
            raise TestFailure(f"Test {test_idx+1}: did not finish within {MAX_CYCLES} cycles")

        if expected is None:
            if not no_solution:
                raise TestFailure(f"Test {test_idx+1}: expected no solution, but got outputs: {outputs}")
        else:
            if no_solution:
                raise TestFailure(f"Test {test_idx+1}: expected solution, but got no_solution")
            if len(outputs) != n_actual:
                raise TestFailure(f"Test {test_idx+1}: expected {n_actual} outputs, got {len(outputs)}")
            if outputs != expected:
                raise TestFailure(f"Test {test_idx+1}: outputs mismatch. Expected {expected}, got {outputs}")

        cocotb.log.info(f"Test {test_idx+1} passed")

    cocotb.log.info("All tests passed")