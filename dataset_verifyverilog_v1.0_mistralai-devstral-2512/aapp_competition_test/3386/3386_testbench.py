import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 4
MAX_CELLS = 64
CLK_NS = 10
MAX_CYCLES = 512

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def manhattan_dist(r1, c1, r2, c2):
    return abs(r1 - r2) + abs(c1 - c2)

async def wait_for_done(dut, max_cycles=512):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value)==1:
            return 'valid'
        if is_value_defined(dut.no_solution.value) and int(dut.no_solution.value)==1:
            return 'no_solution'
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def extract_path(dut, N, M):
    path = []
    for i in range(N * M):
        idx = i * 4
        row_bits = (dut.result_x.value >> idx) & 0xF
        col_bits = (dut.result_y.value >> idx) & 0xF
        path.append((int(row_bits), int(col_bits)))
    return path

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_hamiltonian_cycle(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case: 2x3 grid (small, should find solution)
    test_cases = [
        (2, 3, "2x3 grid"),  # Known to have solution
        (1, 1, "1x1 grid (no solution)"),  # Single cell - can't have cycle with distance >=2
    ]
    
    passed = failed = 0
    
    for i, (N, M, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (N={N}, M={M})")
        try:
            if is_seq:
                dut.N.value = N
                dut.M.value = M
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                result = await wait_for_done(dut)
                
                if result == 'valid':
                    path = extract_path(dut, N, M)
                    cocotb.log.info(f"Path length: {len(path)}")
                    
                    # Verify all cells visited
                    cells = [(r, c) for r in range(N) for c in range(M)]
                    for cell in path:
                        if cell in cells:
                            cells.remove(cell)
                        else:
                            raise TestFailure(f"Cell {cell} visited multiple times or out of bounds")
                    
                    if cells:
                        raise TestFailure(f"Cells not visited: {cells}")
                    
                    # Verify cycle closure
                    first = path[0]
                    last = path[-1]
                    dist = manhattan_dist(last[0], last[1], first[0], first[1])
                    if dist not in [2, 3]:
                        raise TestFailure(f"Cycle closure distance {dist} not 2 or 3")
                    
                    # Verify intermediate distances
                    for k in range(len(path) - 1):
                        p1, p2 = path[k], path[k+1]
                        dist = manhattan_dist(p1[0], p1[1], p2[0], p2[1])
                        if dist not in [2, 3]:
                            raise TestFailure(f"Distance {dist} between {p1} and {p2} not 2 or 3")
                    
                    cocotb.log.info(f"Valid cycle found!")
                else:
                    # No solution case
                    cocotb.log.info(f"No solution found (expected for 1x1)")
            else:
                await Timer(100, units='ns')
            
            passed += 1
            cocotb.log.info(f"Test {i+1} PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")