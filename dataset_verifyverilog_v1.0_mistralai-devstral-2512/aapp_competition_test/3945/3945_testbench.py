import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_N = 16
MAX_M = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pack_grid(grid, rows, cols, width=DATA_WIDTH):
    packed = 0
    for r in range(rows):
        for c in range(cols):
            val = clamp_to_width(grid[r][c], width)
            index = r * MAX_M + c
            packed |= (val << (index * width))
    return packed

def unpack_result(packed_val, rows, cols, width=DATA_WIDTH):
    res = [[0]*cols for _ in range(rows)]
    for r in range(rows):
        for c in range(cols):
            index = r * MAX_M + c
            shift = index * width
            mask = (1 << width) - 1
            res[r][c] = (packed_val >> shift) & mask
    return res

def get_expected(grid, n, m):
    # Python reference implementation
    rows = []
    for i in range(n):
        row = set()
        for j in range(m):
            row.add(grid[i][j])
        rows.append({x: i for i, x in enumerate(sorted(row))})

    columns = []
    for j in range(m):
        col = set()
        for i in range(n):
            col.add(grid[i][j])
        columns.append({x: i for i, x in enumerate(sorted(col))})

    ans = []
    for i in range(n):
        row_ans = []
        for j in range(m):
            val = grid[i][j]
            idx1 = rows[i][val]
            idx2 = columns[j][val]
            row_ans.append(max(idx1, idx2) + max(len(rows[i]) - idx1, len(columns[j]) - idx2))
        ans.append(row_ans)
    return ans

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_grid_module(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    test_cases = [
        (2, 3, [[1, 2, 1], [2, 1, 2]]),
        (2, 2, [[1, 2], [3, 4]]),
        (1, 1, [[1543]]),
        (2, 1, [[179], [1329]]),
        (2, 2, [[1, 2], [2, 1]]),
        (1, 2, [[57, 57]]),
        (3, 3, [[1, 2, 3], [4, 5, 6], [7, 8, 9]]),
    ]

    for i, (n, m, grid) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {n}x{m} grid")
        try:
            expected = get_expected(grid, n, m)
            packed_input = pack_grid(grid, n, m)
            
            # Set inputs
            dut.start.value = 1
            if has_signal(dut, 'grid_flat'):
                dut.grid_flat.value = packed_input
            elif has_signal(dut, 'grid_flat_i'):
                # Handle flattened input if packed differently, assuming 16x16 flat
                for r in range(n):
                    for c in range(m):
                        idx = r * MAX_M + c
                        getattr(dut, f'grid_flat_{idx}').value = clamp_to_width(grid[r][c], DATA_WIDTH)
            
            if has_signal(dut, 'n'):
                dut.n.value = n
            if has_signal(dut, 'm'):
                dut.m.value = m

            await RisingEdge(dut.clk)
            dut.start.value = 0

            # Wait for done
            timeout = 200
            done_found = False
            for _ in range(timeout):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_found = True
                    break
            
            if not done_found:
                raise TestFailure(f"Timeout waiting for done signal")

            # Read result
            if has_signal(dut, 'result_flat'):
                result_val = int(dut.result_flat.value)
                result = unpack_result(result_val, n, m)
            elif has_signal(dut, 'result_flat_i'):
                result = [[0]*m for _ in range(n)]
                for r in range(n):
                    for c in range(m):
                        idx = r * MAX_M + c
                        result[r][c] = int(getattr(dut, f'result_flat_{idx}').value)
            else:
                raise TestFailure("Result signal not found")

            # Check
            for r in range(n):
                for c in range(m):
                    if result[r][c] != expected[r][c]:
                        raise TestFailure(f"Mismatch at ({r},{c}): expected {expected[r][c]}, got {result[r][c]}")
            
            cocotb.log.info(f"Test {i+1} passed")

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise
