import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
# ============================================================================
def is_value_defined(value):
    '''Check if a cocotb value is defined (not X or Z).'''
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    '''Safely convert cocotb value to int, returning default if X/Z.'''
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    '''Convert unsigned integer to signed (two's complement).'''
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    '''Convert signed integer to unsigned for Verilog assignment.'''
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    '''Check if DUT has a signal with given name.'''
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    '''Clamp value to fit within specified bit width.'''
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================
N_MAX = 8
M_MAX = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def is_acyclic(n, edges):
    indeg = [0]*n
    adj = [[] for _ in range(n)]
    for u, v in edges:
        adj[u].append(v)
        indeg[v] += 1
    queue = [i for i in range(n) if indeg[i]==0]
    visited = 0
    while queue:
        u = queue.pop()
        visited += 1
        for v in adj[u]:
            indeg[v] -= 1
            if indeg[v]==0:
                queue.append(v)
    return visited == n

def check_solution(n, m, src, dst, r, remove_list):
    if r < 0 or r > m//2:
        return False
    if len(set(remove_list)) != r:
        return False
    for idx in remove_list:
        if idx < 1 or idx > m:
            return False
    remaining = []
    for i in range(m):
        if (i+1) not in remove_list:
            remaining.append((src[i]-1, dst[i]-1))
    return is_acyclic(n, remaining)

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_cycle_breaker(dut):
    '''Test the CycleBreaker module.'''
    
    # Detect if sequential (has clk)
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, m, edges, description)
    # edges is list of (u, v) 1-based
    test_cases = [
        (2, 2, [(1,2), (2,1)], 'Two-node cycle'),
        (3, 3, [(1,2), (2,3), (3,1)], 'Three-node cycle'),
        (4, 5, [(1,2), (1,3), (3,2), (2,4), (3,4)], 'Acyclic graph'),
        (4, 5, [(1,2), (2,3), (2,4), (3,1), (4,1)], 'Graph with cycles'),
        (4, 3, [(1,2), (2,3), (3,4)], 'Linear chain'),
    ]
    
    for idx, (n, m, edges, description) in enumerate(test_cases):
        cocotb.log.info(f'Test {idx+1}: {description}')
        
        # Prepare arrays
        src = [0]*M_MAX
        dst = [0]*M_MAX
        for i, (u, v) in enumerate(edges):
            src[i] = u
            dst[i] = v
        
        # Write inputs
        dut.n.value = n
        dut.m.value = m
        
        for i in range(M_MAX):
            dut.src[i].value = clamp_to_width(src[i], 4)
            dut.dst[i].value = clamp_to_width(dst[i], 4)
        
        if is_sequential:
            await start_computation(dut)
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        if not is_value_defined(dut.r.value):
            raise TestFailure(f'Output r is undefined')
        
        r = int(dut.r.value)
        remove_list = []
        for i in range(M_MAX//2):
            if is_value_defined(dut.remove_list[i].value):
                remove_list.append(int(dut.remove_list[i].value))
            else:
                remove_list.append(None)
        
        # Take first r elements that are defined
        actual_remove = []
        for i in range(M_MAX//2):
            if is_value_defined(dut.remove_list[i].value):
                val = int(dut.remove_list[i].value)
                if val != 0 or i < r:
                    actual_remove.append(val)
            else:
                break
        actual_remove = actual_remove[:r]
        
        cocotb.log.info(f'  r = {r}, remove_list = {actual_remove}')
        
        if not check_solution(n, m, src, dst, r, actual_remove):
            raise TestFailure(f'Invalid solution: r={r}, list={actual_remove}')
        
        cocotb.log.info(f'  PASS')
    
    cocotb.log.info(f'All tests passed')