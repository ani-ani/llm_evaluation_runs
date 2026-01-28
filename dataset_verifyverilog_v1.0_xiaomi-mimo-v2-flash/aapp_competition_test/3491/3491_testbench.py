import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 100000
MAX_OPS = 250000

# Helper functions from specification
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_edges(edges, N):
    """Convert list of (i,j) edges to packed bitmask"""
    bitmask = 0
    for (i, j) in edges:
        if i > j:
            i, j = j, i
        idx = i * N + j
        bitmask |= (1 << idx)
    return bitmask

def unpack_edges(bitmask, N):
    """Convert packed bitmask to list of edges"""
    edges = []
    for i in range(N):
        for j in range(i + 1, N):
            idx = i * N + j
            if (bitmask >> idx) & 1:
                edges.append((i, j))
    return edges

def apply_operation_to_edges(edges, op_type, vertex, N):
    """Apply R or G operation to edges, return new edge set"""
    new_edges = set()
    for (u, v) in edges:
        # Check if edge is connected to vertex
        if u == vertex or v == vertex:
            # Determine the other endpoint
            other = v if u == vertex else u
            # Apply rotation: RED = +1, GREEN = -1
            if op_type == 'R':
                new_other = (other + 1) % N
            else:  # 'G'
                new_other = (other - 1) % N
            
            # Handle collision: if new_other == vertex, go to next
            if new_other == vertex:
                if op_type == 'R':
                    new_other = (vertex + 1) % N
                else:
                    new_other = (vertex - 1) % N
            
            # Add new edge (undirected)
            if new_other < vertex:
                new_edges.add((new_other, vertex))
            else:
                new_edges.add((vertex, new_other))
        else:
            # Edge not connected to vertex, unchanged
            if u < v:
                new_edges.add((u, v))
            else:
                new_edges.add((v, u))
    return new_edges

async def simulate_sequence(graph, ops, N):
    """Simulate applying operations to graph"""
    edges = set()
    for (i, j) in graph:
        if i < j:
            edges.add((i, j))
        else:
            edges.add((j, i))
    
    for op, vertex in ops:
        edges = apply_operation_to_edges(edges, op, vertex, N)
    return edges

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_staircase_transformation(dut):
    """Test the staircase transformation module"""
    
    # Check required signals
    required_signals = ['clk', 'rst_n', 'start', 'N', 'M', 
                        'current_edges', 'target_edges', 
                        'seq_out', 'seq_wr', 'done', 'error']
    missing = []
    for sig in required_signals:
        if not has_signal(dut, sig):
            missing.append(sig)
    if missing:
        raise TestFailure(f"Missing required signals: {missing}")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test case from example
    test_cases = [
        {
            'name': 'Example 1',
            'N': 5, 'M': 4,
            'current': [(0,1), (0,3), (1,2), (2,4)],
            'target': [(0,2), (0,4), (2,3), (2,4)],
            'expected_ops': [('R', 0), ('G', 2)]
        },
        {
            'name': 'Example 2 (identity)',
            'N': 3, 'M': 3,
            'current': [(0,1), (0,2), (1,2)],
            'target': [(0,1), (1,2), (0,2)],
            'expected_ops': []
        },
        {
            'name': 'Simple case',
            'N': 4, 'M': 2,
            'current': [(0,1), (2,3)],
            'target': [(0,2), (1,3)],
            'expected_ops': []  # May need to verify algorithm
        }
    ]
    
    for test in test_cases:
        cocotb.log.info(f"Running test: {test['name']}")
        
        N = test['N']
        M = test['M']
        
        # Pack edges into bitmasks
        current_edges = pack_edges(test['current'], N)
        target_edges = pack_edges(test['target'], N)
        
        # Set inputs
        dut.N.value = N
        dut.M.value = M
        dut.current_edges.value = current_edges
        dut.target_edges.value = target_edges
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect output operations
        ops = []
        cycle_count = 0
        
        while cycle_count < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycle_count += 1
            
            # Check for output
            if is_value_defined(dut.seq_wr.value) and int(dut.seq_wr.value) == 1:
                seq_val = int(dut.seq_out.value)
                op_type = 'R' if (seq_val >> 6) & 3 == 0 else 'G'
                vertex = seq_val & 0x3F
                ops.append((op_type, vertex))
                
                if len(ops) > MAX_OPS:
                    raise TestFailure(f"Too many operations: {len(ops)} > {MAX_OPS}")
            
            # Check for done
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            
            # Check for error
            if is_value_defined(dut.error.value) and int(dut.error.value) == 1:
                raise TestFailure("Module reported error")
        else:
            raise TestFailure(f"Computation timed out after {cycle_count} cycles")
        
        cocotb.log.info(f"Collected {len(ops)} operations: {ops}")
        
        # Simulate the operations and verify result
        final_edges = await simulate_sequence(test['current'], ops, N)
        target_edges_set = set(tuple(sorted(e)) for e in test['target'])
        
        if final_edges != target_edges_set:
            raise TestFailure(
                f"Final edges don't match target.\n"
                f"Expected: {sorted(target_edges_set)}\n"
                f"Got: {sorted(final_edges)}"
            )
        
        cocotb.log.info(f"{test['name']} PASSED")
    
    # Additional randomized test
    cocotb.log.info("Running random test...")
    random.seed(42)
    N = 4
    M = random.randint(0, 6)
    
    # Generate random current graph
    all_possible = [(i, j) for i in range(N) for j in range(i + 1, N)]
    current = random.sample(all_possible, M) if M > 0 and len(all_possible) >= M else []
    
    # Generate random target graph
    target = random.sample(all_possible, M) if M > 0 and len(all_possible) >= M else []
    
    current_edges = pack_edges(current, N)
    target_edges = pack_edges(target, N)
    
    dut.N.value = N
    dut.M.value = M
    dut.current_edges.value = current_edges
    dut.target_edges.value = target_edges
    dut.start.value = 1
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    ops = []
    cycle_count = 0
    
    while cycle_count < MAX_CYCLES:
        await RisingEdge(dut.clk)
        cycle_count += 1
        
        if is_value_defined(dut.seq_wr.value) and int(dut.seq_wr.value) == 1:
            seq_val = int(dut.seq_out.value)
            op_type = 'R' if (seq_val >> 6) & 3 == 0 else 'G'
            vertex = seq_val & 0x3F
            ops.append((op_type, vertex))
            
            if len(ops) > MAX_OPS:
                raise TestFailure(f"Too many operations: {len(ops)} > {MAX_OPS}")
        
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        
        if is_value_defined(dut.error.value) and int(dut.error.value) == 1:
            raise TestFailure("Module reported error")
    else:
        raise TestFailure(f"Random test timed out after {cycle_count} cycles")
    
    # Verify result
    final_edges = await simulate_sequence(current, ops, N)
    target_edges_set = set(tuple(sorted(e)) for e in target)
    
    if final_edges != target_edges_set:
        raise TestFailure(
            f"Random test failed.\n"
            f"Current: {current}\n"
            f"Target: {target}\n"
            f"Ops: {ops}\n"
            f"Expected: {sorted(target_edges_set)}\n"
            f"Got: {sorted(final_edges)}"
        )
    
    cocotb.log.info(f"Random test PASSED with {len(ops)} operations")
