import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 2000

# --- Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if v is None: return 0
    val = int(v)
    max_val = (1 << bits) - 1
    if val < 0: return 0
    return min(val, max_val)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# --- Input Builders ---
def build_adj_matrix(n, edges):
    matrix = [[0]*16 for _ in range(16)]
    for u, v in edges:
        if u < 16 and v < 16:
            matrix[u][v] = 1
            matrix[v][u] = 1
    return matrix

async def set_inputs(dut, n, k, edges):
    # Set n and k
    if has_signal(dut, 'n'):
        dut.n.value = n
    if has_signal(dut, 'k'):
        dut.k.value = k
    
    # Set Adjacency Matrix
    matrix = build_adj_matrix(n, edges)
    for i in range(16):
        for j in range(16):
            if has_signal(dut, f'adj_matrix_{i}_{j}'):
                getattr(dut, f'adj_matrix_{i}_{j}').value = matrix[i][j]
            elif has_signal(dut, 'adj_matrix'):
                # If packed or 2D array access works in simulator
                # Usually cocotb handles 2D arrays by index
                try:
                    dut.adj_matrix[i][j].value = matrix[i][j]
                except Exception:
                    pass

# --- Test Logic ---
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_k_multihedgehog(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)

    # Test Cases: (n, k, edges, expected_result, description)
    # n and k are unscaled (original problem scale)
    # We rely on the module to handle 4-bit inputs (max 15)
    # Cases where n>15 are skipped or scaled down for this specific testbench
    test_cases = [
        # Case 1: Valid 1-multihedgehog (Star graph)
        # 5 nodes: 0 center, 1,2,3,4 leaves
        (5, 1, [(0,1), (0,2), (0,3), (0,4)], 1, "Valid k=1 (Star 5)"),
        
        # Case 2: Invalid 1-multihedgehog (Degree 2 center)
        # 3 nodes: 0-1-2 (Center 1 has degree 2)
        (3, 1, [(0,1), (1,2)], 0, "Invalid k=1 (Degree 2 center)"),

        # Case 3: Valid 2-multihedgehog
        # Center 0 connected to 3 arms: (1,2), (3,4), (5,6)
        # Each arm is a star (center, leaf)
        (7, 2, [(0,1), (1,2), (0,3), (3,4), (0,5), (5,6)], 1, "Valid k=2"),

        # Case 4: Invalid 2-multihedgehog (Arms not valid)
        # Center 0 connected to arm (1,2) [valid] and arm (3) [invalid, just a leaf]
        (4, 2, [(0,1), (1,2), (0,3)], 0, "Invalid k=2 (Bad arm)"),

        # Case 5: Simple Tree (Path of 3)
        (3, 2, [(0,1), (1,2)], 0, "Path 3, k=2"),

        # Case 6: Small Star, k=1
        # 4 nodes: center 0, leaves 1,2,3
        (4, 1, [(0,1), (0,2), (0,3)], 1, "Valid k=1 (Star 4)"),

        # Case 7: Star, k=2 (Should fail, arms are not 1-multihedgehogs)
        (4, 2, [(0,1), (0,2), (0,3)], 0, "Star k=2 (Arms are leaves)"),

        # Case 8: Valid k=1, but input k=2
        (5, 2, [(0,1), (0,2), (0,3), (0,4)], 0, "Star k=1 given as k=2"),
    ]

    passed = 0
    failed = 0

    for i, (n, k, edges, expected, desc) in enumerate(test_cases):
        # Skip if n > 15 as our interface is 4-bit (0-15)
        if n > 15:
            cocotb.log.info(f"Skipping Test {i+1}: n={n} > 15 (Interface limit)")
            continue
        
        if k > 15:
            cocotb.log.info(f"Skipping Test {i+1}: k={k} > 15 (Interface limit)")
            continue

        cocotb.log.info(f"Test {i+1}: {desc} (n={n}, k={k}, edges={len(edges)})")
        try:
            await set_inputs(dut, n, k, edges)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')

            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
