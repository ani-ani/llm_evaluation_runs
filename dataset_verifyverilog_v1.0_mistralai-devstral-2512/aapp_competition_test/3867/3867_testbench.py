import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 5  # Node numbers 0-15 (1-16)
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 500

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    mask = (1 << bits) - 1
    return v & mask

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_bits(vals, bits_per_val=5):
    packed = 0
    for i, v in enumerate(vals):
        packed |= (v & ((1 << bits_per_val) - 1)) << (i * bits_per_val)
    return packed

def pack_matrix(adj_matrix, node_count=16, bits_per_node=16):
    packed = 0
    for i in range(node_count):
        row_val = 0
        for j in range(node_count):
            if adj_matrix[i][j]:
                row_val |= (1 << j)
        packed |= (row_val << (i * bits_per_node))
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'seq_valid'):
        dut.seq_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_sequence(dut, seq, seq_len):
    """Load sequence data over seq_len cycles"""
    dut.seq_valid.value = 1
    for i in range(seq_len):
        dut.seq_data.value = clamp_to_width(seq[i], DATA_WIDTH)
        await RisingEdge(dut.clk)
    dut.seq_valid.value = 0

def build_tree_adj(n, edges):
    """Build adjacency matrix for tree with n nodes (1-indexed)"""
    adj = [[0]*16 for _ in range(16)]
    for u, v in edges:
        u_idx = u - 1
        v_idx = v - 1
        if u_idx < 16 and v_idx < 16:
            adj[u_idx][v_idx] = 1
            adj[v_idx][u_idx] = 1
    return adj

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_bfs_validator(dut):
    # Setup
    assert has_signal(dut, 'clk'), "Module must have clk signal"
    assert has_signal(dut, 'rst_n'), "Module must have rst_n signal"
    assert has_signal(dut, 'start'), "Module must have start signal"
    assert has_signal(dut, 'done'), "Module must have done signal"
    assert has_signal(dut, 'result'), "Module must have result signal"
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, edges, sequence, expected_result)
    test_cases = [
        # Simple cases
        (1, [], [1], True),
        (2, [(1, 2)], [1, 2], True),
        (2, [(1, 2)], [2, 1], False),
        (3, [(1, 2), (1, 3)], [1, 2, 3], True),
        (3, [(1, 2), (1, 3)], [1, 3, 2], True),
        (3, [(1, 2), (1, 3)], [1, 2, 4], False),
        (3, [(1, 2), (1, 3)], [2, 1, 3], False),
        (3, [(1, 2), (1, 3)], [1, 2, 3, 4], False),
        # Line graph
        (4, [(1, 2), (2, 3), (3, 4)], [1, 2, 3, 4], True),
        (4, [(1, 2), (2, 3), (3, 4)], [1, 2, 4, 3], False),
        # Star graph
        (4, [(1, 2), (1, 3), (2, 4)], [1, 2, 3, 4], True),
        (4, [(1, 2), (1, 3), (2, 4)], [1, 2, 4, 3], False),
        # Larger tree
        (5, [(1, 2), (1, 3), (2, 4), (2, 5)], [1, 2, 3, 4, 5], True),
        (5, [(1, 2), (1, 3), (2, 4), (2, 5)], [1, 2, 3, 5, 4], True),
        (5, [(1, 2), (1, 3), (2, 4), (2, 5)], [1, 3, 2, 4, 5], True),
        (5, [(1, 2), (1, 3), (2, 4), (2, 5)], [1, 2, 3, 5, 4], True),
        # Invalid cases
        (4, [(1, 2), (1, 3), (2, 4)], [1, 2, 3, 4, 5], False),
        (4, [(1, 2), (1, 3), (2, 4)], [1, 2, 4, 3], False),
        (3, [(1, 2), (1, 3)], [1, 2, 3, 4], False),
        (3, [(1, 2), (1, 3)], [1, 2, 3], True),
        # Random tests
        (6, [(1, 2), (1, 5), (2, 3), (2, 4), (5, 6)], [1, 2, 5, 3, 4, 6], True),
        (6, [(1, 2), (1, 5), (2, 3), (2, 4), (5, 6)], [1, 5, 2, 3, 4, 6], True),
        (6, [(1, 2), (1, 5), (2, 3), (2, 4), (5, 6)], [1, 2, 5, 3, 6, 4], False),
        # Edge: single node
        (1, [], [1], True),
        (1, [], [2], False),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, edges, seq, expected) in enumerate(test_cases):
        # Skip if n > 16 (our hardware limit)
        if n > 16:
            cocotb.log.info(f"Test {i+1}: Skipping (n={n} > 16)")
            continue
            
        # Prepare adjacency matrix
        adj = build_tree_adj(n, edges)
        packed_adj = pack_matrix(adj, node_count=n)
        
        # Prepare sequence (convert to 0-indexed, pad to 16 if needed)
        seq_0idx = [x - 1 for x in seq]
        seq_padded = seq_0idx + [0] * (16 - len(seq_0idx))
        
        cocotb.log.info(f"Test {i+1}: n={n}, seq={seq}, expected={'Yes' if expected else 'No'}")
        
        try:
            # Reset
            await reset_dut(dut)
            
            # Load adjacency matrix (assuming it's loaded before start, or via separate interface)
            # For simplicity, assume adjacency is loaded via a separate mechanism or hardcoded
            # We'll test with a simpler assumption: the DUT knows the graph structure.
            # Since the spec requires graph input, we need to simulate that.
            # In this simplified test, we assume DUT has a way to input graph.
            # Let's add a graph loading phase if the DUT has graph input signals.
            
            # Check if DUT has graph input signals
            if has_signal(dut, 'graph_in'):
                # Load adjacency matrix
                dut.graph_in.value = packed_adj
                await RisingEdge(dut.clk)
            else:
                # Assume graph is pre-configured in test, DUT has internal state
                cocotb.log.warning("DUT lacks graph_in signal, assuming pre-configured graph")
            
            # Start loading sequence
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Load sequence data over seq_len cycles
            if has_signal(dut, 'seq_valid') and has_signal(dut, 'seq_data'):
                await load_sequence(dut, seq_padded, len(seq_0idx))
            elif has_signal(dut, 'seq_len'):
                dut.seq_len.value = len(seq_0idx)
                await load_sequence(dut, seq_padded, len(seq_0idx))
            else:
                # If no seq_valid/seq_data, assume sequence is loaded in parallel
                # For simplicity, we'll use a parallel array interface
                for idx, node in enumerate(seq_0idx):
                    if has_signal(dut, f'seq_{idx}'):
                        getattr(dut, f'seq_{idx}').value = clamp_to_width(node, DATA_WIDTH)
                if has_signal(dut, 'seq_len'):
                    dut.seq_len.value = len(seq_0idx)
                await RisingEdge(dut.clk)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            expected_val = 1 if expected else 0
            
            if result_val != expected_val:
                raise TestFailure(f"Expected {'Yes' if expected else 'No'}, got {'Yes' if result_val else 'No'}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    cocotb.log.info(f"Test Summary: Passed={passed}, Failed={failed}")
    if failed:
        raise TestFailure(f"{failed} tests failed")
