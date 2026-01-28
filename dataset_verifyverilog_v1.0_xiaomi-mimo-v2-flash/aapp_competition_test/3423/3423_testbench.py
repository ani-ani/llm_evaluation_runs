import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
DATA_WIDTH = 4
ARRAY_SIZE = 10
CLK_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'edge_wr'): dut.edge_wr.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_edge(dut, src, dst):
    dut.edge_from.value = clamp_to_width(src, DATA_WIDTH)
    dut.edge_to.value = clamp_to_width(dst, DATA_WIDTH)
    dut.edge_wr.value = 1
    await RisingEdge(dut.clk)
    dut.edge_wr.value = 0

async def read_results(dut, num_nodes):
    results = []
    for i in range(num_nodes):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_idx.value):
            results.append(int(dut.result_idx.value))
    return results

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_topological_sort(dut):
    if not (has_signal(dut, 'clk') and has_signal(dut, 'rst_n')):
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test case 1: Simple DAG (should sort)
    # Nodes: 0,1,2,3 (4 nodes)
    # Edges: 2->0, 2->1, 0->3, 1->3
    # Expected order: 2,0,1,3 or 2,1,0,3
    # With priority queue (min index first): 2,0,1,3
    test_cases = [
        {
            'name': 'Simple DAG',
            'nodes': 4,
            'edges': [(2,0), (2,1), (0,3), (1,3)],
            'expected': [2,0,1,3],
            'should_fail': False
        },
        {
            'name': 'Cycle (0->1, 1->0)',
            'nodes': 2,
            'edges': [(0,1), (1,0)],
            'expected': None,
            'should_fail': True
        },
        {
            'name': 'Single node',
            'nodes': 1,
            'edges': [],
            'expected': [0],
            'should_fail': False
        },
        {
            'name': 'Two independent nodes',
            'nodes': 2,
            'edges': [],
            'expected': [0,1],
            'should_fail': False
        },
        {
            'name': 'Chain 0->1->2',
            'nodes': 3,
            'edges': [(0,1), (1,2)],
            'expected': [0,1,2],
            'should_fail': False
        }
    ]
    
    for test in test_cases:
        cocotb.log.info(f"Testing: {test['name']}")
        await reset_dut(dut)
        
        # Load edges
        for src, dst in test['edges']:
            await write_edge(dut, src, dst)
        
        # Start sorting
        dut.num_nodes.value = clamp_to_width(test['nodes'], DATA_WIDTH)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
            
            # Check cycle detection
            if has_signal(dut, 'cycle_detected'):
                cycle = int(dut.cycle_detected.value)
                if test['should_fail'] and not cycle:
                    raise TestFailure(f"Expected cycle but didn't detect one")
                if not test['should_fail'] and cycle:
                    raise TestFailure(f"Unexpected cycle detected")
            
            if test['should_fail']:
                if has_signal(dut, 'result_empty'):
                    empty = int(dut.result_empty.value)
                    if not empty:
                        raise TestFailure(f"Expected empty result for cyclic case")
                # For cyclic, we just check done is high
                continue
            
            # Read results
            results = await read_results(dut, test['nodes'])
            
            if len(results) != test['nodes']:
                raise TestFailure(f"Expected {test['nodes']} results, got {len(results)}")
            
            if results != test['expected']:
                raise TestFailure(f"Expected {test['expected']}, got {results}")
            
            cocotb.log.info(f"PASS: {results}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL {test['name']}: {e}")
            raise

# Additional test: Multiple valid orders
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_multiple_orders(dut):
    if not (has_signal(dut, 'clk') and has_signal(dut, 'rst_n')):
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Graph: 0 and 1 both depend on 2, 2->0, 2->1
    # Valid orders: 2,0,1 or 2,1,0
    # Lexicographically first should be 2,0,1
    test = {
        'nodes': 3,
        'edges': [(2,0), (2,1)],
        'expected': [2,0,1]  # Priority queue gives min index first
    }
    
    for src, dst in test['edges']:
        await write_edge(dut, src, dst)
    
    dut.num_nodes.value = clamp_to_width(test['nodes'], DATA_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    results = await read_results(dut, test['nodes'])
    
    if results != test['expected']:
        raise TestFailure(f"Expected {test['expected']}, got {results}")
    
    cocotb.log.info(f"PASS: Multiple order test, got {results}")
