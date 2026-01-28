import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Co-referenced test cases from problem
test_cases = [
    ("1 1 2 3 1 0", "2 4 20", 3),
    ("1 1 2 3 1 0", "15 27 26", 2),
    ("1 1 2 3 1 0", "2 2 1", 0),
    ("9999999999999999 1 2 2 0 0", "10000000000000000 1 10000000000000000", 1),
    ("9999999999999999 1 2 2 0 0", "9999999999999999 1 10000000000000000", 2),
    ("9999999999999998 1 2 2 0 0", "9999999999999999 1 10000000000000000", 2),
    ("1 1 2 2 0 0", "1 1 10000000000000000", 53),
    ("1 1 2 2 0 0", "1 2 1", 1),
    ("1 9999999999999999 2 2 0 0", "1 10000000000000000 10000000000000000", 1),
    ("1 9999999999999998 2 2 0 0", "1 9999999999999999 10000000000000000", 2),
]

async def parse_input(line):
    return [int(x) for x in line.split()]

async def calc_expected(x0, y0, ax, ay, bx, by, xs, ys, t):
    # Generate nodes
    nodes = [(x0, y0)]
    for _ in range(63):
        nx = nodes[-1][0] * ax + bx
        ny = nodes[-1][1] * ay + by
        if nx > 10**18 or ny > 10**18:
            break
        nodes.append((nx, ny))
    
    # Calculate max nodes
    best = 0
    for i in range(len(nodes)):
        for j in range(i, len(nodes)):
            dist_start_to_i = abs(xs - nodes[i][0]) + abs(ys - nodes[i][1])
            dist_i_to_j = abs(nodes[i][0] - nodes[j][0]) + abs(nodes[i][1] - nodes[j][1])
            if dist_start_to_i + dist_i_to_j <= t:
                best = max(best, j - i + 1)
    return best

async def setup_inputs(dut, x0, y0, ax, ay, bx, by, xs, ys, t):
    dut.x0.value = clamp_to_width(x0, 64)
    dut.y0.value = clamp_to_width(y0, 64)
    dut.ax.value = clamp_to_width(ax, 8)
    dut.ay.value = clamp_to_width(ay, 8)
    dut.bx.value = clamp_to_width(bx, 64)
    dut.by.value = clamp_to_width(by, 64)
    dut.xs.value = clamp_to_width(xs, 64)
    dut.ys.value = clamp_to_width(ys, 64)
    dut.t.value = clamp_to_width(t, 64)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_os_space_collector(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just set inputs and wait
        await Timer(100, units='ns')
    
    passed = 0
    failed = 0
    
    for i, ((line1, line2), expected) in enumerate(zip(
        [("1 1 2 3 1 0", "2 4 20"), ("1 1 2 3 1 0", "15 27 26"), ("1 1 2 3 1 0", "2 2 1")],
        [3, 2, 0]
    )):
        cocotb.log.info(f"Test {i+1}: Case {line1} / {line2}")
        
        try:
            x0, y0, ax, ay, bx, by = await parse_input(line1)
            xs, ys, t_val = await parse_input(line2)
            
            # Calculate expected result using Python
            exp = await calc_expected(x0, y0, ax, ay, bx, by, xs, ys, t_val)
            
            await setup_inputs(dut, x0, y0, ax, ay, bx, by, xs, ys, t_val)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=5000)
            else:
                await Timer(1000, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{passed}")
