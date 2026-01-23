import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return value + (1 << bits) if value < 0 else value
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

def reference_forest(V, degrees):
    if V == 0:
        return True, []
    sum_deg = sum(degrees)
    if sum_deg % 2 != 0:
        return False, []
    m = sum(1 for d in degrees if d > 0)
    max_deg = max(degrees) if V > 0 else 0
    if m > 0:
        if max_deg > m - 1 or sum_deg > 2 * (m - 1):
            return False, []
    if sum_deg == 0:
        return True, []
    comp_id = list(range(V))
    deg = list(degrees)
    edges = []
    while True:
        u = -1
        best_deg = -1
        for i in range(V):
            if deg[i] > best_deg:
                best_deg = deg[i]
                u = i
        if u == -1:
            break
        v = -1
        for j in range(V):
            if j != u and deg[j] > 0 and comp_id[j] != comp_id[u]:
                v = j
                break
        if v == -1:
            return False, []
        edges.append((u+1, v+1))
        deg[u] -= 1
        deg[v] -= 1
        old_id = comp_id[v]
        new_id = comp_id[u]
        for i in range(V):
            if comp_id[i] == old_id:
                comp_id[i] = new_id
    return True, edges

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_forest_builder(dut):
    MAX_V = 8
    DATA_WIDTH = 8
    CLK_PERIOD_NS = 10
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    test_cases = [
        (3, [1,1,2], True, [(1,3),(2,3)]),
        (2, [1,2], False, []),
        (3, [2,2,2], False, []),
        (0, [], True, []),
        (5, [2,2,1,1,0], True, [(1,3),(1,4),(2,5)]),
        (4, [1,1,1,1], True, [(1,2),(3,4)]),
    ]
    for i, (V, degrees, exp_possible, exp_edges) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: V={V}, degrees={degrees}")
        if has_signal(dut, 'V'):
            dut.V.value = V
        if has_signal(dut, 'degrees'):
            for idx in range(MAX_V):
                if idx < V:
                    getattr(dut, 'degrees')[idx].value = clamp_to_width(degrees[idx], DATA_WIDTH)
                else:
                    getattr(dut, 'degrees')[idx].value = 0
        if is_sequential:
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        if not is_value_defined(dut.possible.value):
            raise TestFailure(f"Test {i+1}: possible undefined")
        actual_possible = int(dut.possible.value) == 1
        if actual_possible != exp_possible:
            raise TestFailure(f"Test {i+1}: expected possible={exp_possible}, got {actual_possible}")
        if exp_possible:
            edges = []
            for _ in range(20):
                if is_sequential:
                    await RisingEdge(dut.clk)
                if is_value_defined(dut.edge_valid.value) and int(dut.edge_valid.value) == 1:
                    a = int(dut.edge_a.value)
                    b = int(dut.edge_b.value)
                    edges.append((a, b))
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            if set(edges) != set(exp_edges):
                raise TestFailure(f"Test {i+1}: expected edges {exp_edges}, got {edges}")
            dut._log.info(f"Test {i+1}: PASS")
        else:
            dut._log.info(f"Test {i+1}: PASS (IMPOSSIBLE)")
    dut._log.info("All tests passed!")