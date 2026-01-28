import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 2000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'edge_valid'): dut.edge_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def format_input(n, edges, m, edges_b):
    # Returns list of (u, v, tree_sel) tuples to feed
    data = []
    for u, v in edges:
        data.append((u, v, 0)) # Tree A
    for u, v in edges_b:
        data.append((u, v, 1)) # Tree B
    return data

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_network_cost(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumption (unlikely for this problem, but safe)
        await Timer(100, units='ns')

    # Test Cases from problem
    # Case 1: N=3 (1-2, 2-3), M=4 (Star)
    inputs = [
        {
            'N': 3, 
            'M': 4,
            'edges_A': [(1,2), (2,3)],
            'edges_B': [(1,2), (1,3), (1,4)],
            'expected': 96
        },
        {
            'N': 7,
            'M': 5,
            'edges_A': [(1,2), (2,3), (2,4), (4,5), (5,6), (5,7)],
            'edges_B': [(1,2), (1,3), (1,4), (1,5)],
            'expected': 551
        }
    ]

    for i, tc in enumerate(inputs):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        # Wait for ready
        if has_signal(dut, 'ready'):
            while not int(dut.ready.value):
                await RisingEdge(dut.clk)
        
        # Set N and M
        dut.N.value = clamp_to_width(tc['N'], 4)
        dut.M.value = clamp_to_width(tc['M'], 4)
        await RisingEdge(dut.clk)
        
        # Prepare data stream
        # Need to send N-1 edges for A, then M-1 edges for B
        # Actually, the spec says edge_valid comes with tree_sel.
        # We'll send them sequentially.
        
        # Send Tree A edges
        dut.tree_sel.value = 0
        dut.edge_valid.value = 1
        for u, v in tc['edges_A']:
            dut.edge_u.value = u - 1 # 0-indexed internal
            dut.edge_v.value = v - 1
            await RisingEdge(dut.clk)
        
        # Send Tree B edges
        dut.tree_sel.value = 1
        for u, v in tc['edges_B']:
            dut.edge_u.value = u - 1
            dut.edge_v.value = v - 1
            await RisingEdge(dut.clk)
            
        dut.edge_valid.value = 0
        
        # Trigger Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, 5000) # Increased timeout for complex logic
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result undefined")
        
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {i+1} Passed: {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    cocotb.log.info("All tests passed")