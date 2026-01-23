import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_compute_sum(dut):
    N = 8
    COLOR_WIDTH = 9
    SUM_WIDTH = 16
    MOD = 10**9+7
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    vertices = list(range(N))
    random.shuffle(vertices)
    pos = [0]*N
    for idx, v in enumerate(vertices):
        pos[v] = idx
    c = [0]*N
    for i in range(N-1):
        c[i] = random.randint(1, 300)
    c[N-1] = 0
    color_matrix = [[0]*N for _ in range(N)]
    for i in range(N):
        for j in range(N):
            if i == j:
                color_matrix[i][j] = 0
            else:
                pi = pos[i]
                pj = pos[j]
                if pi < pj:
                    color_matrix[i][j] = c[pi]
                else:
                    color_matrix[i][j] = c[pj]
    if has_signal(dut, 'color'):
        for i in range(N):
            for j in range(N):
                dut.color[i][j].value = clamp_to_width(color_matrix[i][j], COLOR_WIDTH)
    else:
        for i in range(N):
            for j in range(N):
                port_name = f'color_{i}_{j}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(color_matrix[i][j], COLOR_WIDTH)
                else:
                    raise TestFailure(f"Cannot find color port for {i},{j}")
    def is_monochromatic(clique, mat):
        if len(clique) <= 1:
            return True
        first = None
        for idx1 in range(len(clique)):
            for idx2 in range(idx1+1, len(clique)):
                col = mat[clique[idx1]][clique[idx2]]
                if first is None:
                    first = col
                elif col != first:
                    return False
        return True
    def f(S, mat):
        if not S:
            return 0
        max_sz = 1
        S_list = list(S)
        nS = len(S_list)
        for mask in range(1, 1<<nS):
            clique = [S_list[i] for i in range(nS) if (mask>>i)&1]
            if is_monochromatic(clique, mat):
                sz = len(clique)
                if sz > max_sz:
                    max_sz = sz
        return max_sz
    def compute_sum(mat):
        total = 0
        for mask in range(1, 1<<N):
            S = [i for i in range(N) if (mask>>i)&1]
            total += f(S, mat)
        return total % MOD
    expected = compute_sum(color_matrix)
    dut._log.info(f"Expected sum: {expected}")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    cycles = 0
    while cycles < 10000:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        cycles += 1
    else:
        raise TestFailure("Timeout waiting for done")
    if not is_value_defined(dut.sum.value):
        raise TestFailure("Sum output undefined")
    result = int(dut.sum.value)
    if result != expected:
        raise TestFailure(f"Result {result} != expected {expected}")
    dut._log.info("Test passed")