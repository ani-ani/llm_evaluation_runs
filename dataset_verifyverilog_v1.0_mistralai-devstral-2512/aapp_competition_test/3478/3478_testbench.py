import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 256

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pack_edges(edges, n, max_n=16):
    """Pack adjacency matrix into 256-bit value"""
    packed = 0
    for (x, y) in edges:
        if x <= max_n and y <= max_n:
            i, j = x-1, y-1
            packed |= (1 << (i * max_n + j))
            packed |= (1 << (j * max_n + i))
    return packed

def calc_expected_masks(n, edges, max_n=16):
    """Calculate expected partition using Python logic (scaled)"""
    if n > max_n:
        n = max_n
    
    adj = [[0]*n for _ in range(n)]
    for (x, y) in edges:
        if x <= n and y <= n:
            adj[x-1][y-1] = adj[y-1][x-1] = 1
    
    # Constraint: no direct edge between 1 and 2
    if adj[0][1] == 1:
        return 0, 0, 0, False
    
    # Find clique containing node 0 (Winterfell)
    clique_a = [0]
    for i in range(1, n):
        if adj[0][i]:
            ok = True
            for j in clique_a:
                if not adj[i][j]:
                    ok = False
                    break
            if ok:
                clique_a.append(i)
    
    # Remaining nodes (excluding node 1 which is King's Landing)
    remaining = [i for i in range(n) if i not in clique_a and i != 1]
    
    # Find clique containing node 1 (King's Landing)
    clique_b = [1]
    for i in remaining:
        if adj[1][i]:
            ok = True
            for j in clique_b:
                if not adj[i][j]:
                    ok = False
                    break
            if ok:
                clique_b.append(i)
    
    # Verify remaining (if any) form a clique
    leftover = [i for i in range(n) if i not in clique_a and i not in clique_b]
    for i in range(len(leftover)):
        for j in range(i+1, len(leftover)):
            if not adj[leftover[i]][leftover[j]]:
                return 0, 0, 0, False
    
    # Build masks
    mask_a = 0
    for i in clique_a:
        mask_a |= (1 << i)
    mask_b = 0
    for i in clique_b:
        mask_b |= (1 << i)
    mask_c = 0
    for i in leftover:
        mask_c |= (1 << i)
    
    return mask_a, mask_b, mask_c, True

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_partition(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (9, [(1,4),(5,4),(1,5),(6,2),(6,7),(7,2),(3,8),(3,9),(8,9),(6,8),(5,9)], "Sample 1", True),
        (9, [(1,4),(5,4),(1,5),(6,2),(6,7),(7,2),(3,8),(3,9),(6,8),(5,9)], "Sample 2", False),
        (4, [(1,3),(2,4)], "Small OK", True),
        (5, [(1,3),(1,4),(3,4),(2,5)], "Overlap", False),
    ]
    
    passed = failed = 0
    
    for i, (n, edges, desc, should_work) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            if n > 16:
                cocotb.log.warning(f"  Skipping: n={n} > max 16")
                continue
            
            packed = pack_edges(edges, n, 16)
            
            dut.n.value = n
            dut.edges.value = packed
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut, MAX_CYCLES)
            
            valid = int(dut.valid.value)
            exp_mask_a, exp_mask_b, exp_mask_c, exp_valid = calc_expected_masks(n, edges, 16)
            
            if should_work:
                if valid != 1:
                    raise TestFailure(f"Expected valid=1, got {valid}")
                
                got_a = int(dut.arya_mask.value)
                got_b = int(dut.sansa_mask.value)
                got_c = int(dut.other_mask.value)
                
                if (got_a & got_b) or (got_a & got_c) or (got_b & got_c):
                    raise TestFailure(f"Masks overlap: A={bin(got_a)}, B={bin(got_b)}, C={bin(got_c)}")
                
                if not (got_a & 1):
                    raise TestFailure(f"Node 1 not in Arya's collection")
                if not (got_b & 2):
                    raise TestFailure(f"Node 2 not in Sansa's collection")
                
                adj = [[0]*n for _ in range(n)]
                for (x,y) in edges:
                    if x<=n and y<=n:
                        adj[x-1][y-1] = adj[y-1][x-1] = 1
                
                arya_nodes = [idx for idx in range(n) if (got_a >> idx) & 1]
                for j in range(len(arya_nodes)):
                    for k in range(j+1, len(arya_nodes)):
                        if not adj[arya_nodes[j]][arya_nodes[k]]:
                            raise TestFailure(f"Arya's nodes {arya_nodes[j]+1},{arya_nodes[k]+1} not connected")
                
                sansa_nodes = [idx for idx in range(n) if (got_b >> idx) & 1]
                for j in range(len(sansa_nodes)):
                    for k in range(j+1, len(sansa_nodes)):
                        if not adj[sansa_nodes[j]][sansa_nodes[k]]:
                            raise TestFailure(f"Sansa's nodes {sansa_nodes[j]+1},{sansa_nodes[k]+1} not connected")
                
                other_nodes = [idx for idx in range(n) if (got_c >> idx) & 1]
                for j in range(len(other_nodes)):
                    for k in range(j+1, len(other_nodes)):
                        if not adj[other_nodes[j]][other_nodes[k]]:
                            raise TestFailure(f"Other nodes {other_nodes[j]+1},{other_nodes[k]+1} not connected")
                
            else:
                if valid != 0:
                    raise TestFailure(f"Expected valid=0 (impossible), got valid={valid}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")