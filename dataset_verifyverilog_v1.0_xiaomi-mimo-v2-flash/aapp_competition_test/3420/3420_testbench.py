import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
NODE_WIDTH = 4
MAX_NODES = 16
MAX_EDGES = 24
CLK_NS = 10
MAX_CYCLES = 2000

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

def create_book_edges_binary(boy_idx, girl_idx, num_boys):
    # boy_idx is 0..num_boys-1, girl_idx is 0..num_girls-1
    # In graph: boy node = boy_idx, girl node = num_boys + girl_idx
    # Edge format: 4 bits source, 4 bits dest
    source = boy_idx
    dest = num_boys + girl_idx
    edge_val = (source << 4) | dest
    return edge_val

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_book_circle(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Module missing 'clk' signal")

    # Test Cases
    # Case 1: 2 boys, 2 girls, 2 books (1-1 edge, 2-2 edge) -> 2 components
    # Boys: 0=kenny, 1=charlie
    # Girls: 0=jenny, 1=laura
    # Books: (kenny, jenny), (charlie, laura)
    test_cases = [
        {
            "num_boys": 2,
            "num_girls": 2,
            "edges": [(0, 0), (1, 1)],
            "expected": 2,
            "desc": "Disjoint edges (2 components)"
        },
        {
            "num_boys": 2,
            "num_girls": 2,
            "edges": [(0, 0), (0, 1), (1, 0)],
            "expected": 1,
            "desc": "Connected component (3 edges, 1 component)"
        },
        {
            "num_boys": 1,
            "num_girls": 2,
            "edges": [(0, 0), (0, 1)],
            "expected": 1,
            "desc": "Star graph (1 component)"
        },
        {
            "num_boys": 3,
            "num_girls": 3,
            "edges": [(0, 0), (1, 1), (2, 2)],
            "expected": 3,
            "desc": "3 disjoint edges (3 components)"
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {tc['desc']}")
        
        # 1. Setup Inputs
        dut.num_boys.value = clamp_to_width(tc['num_boys'], NODE_WIDTH)
        dut.num_girls.value = clamp_to_width(tc['num_girls'], NODE_WIDTH)
        
        # 2. Pack book edges into the bit vector
        # The spec says: packed array of 24 edges, 8 bits each.
        # We assume the port name is 'book_edges' and it is a single large vector
        if not has_signal(dut, 'book_edges'):
             raise TestFailure("Module missing 'book_edges' signal")
             
        packed_edges = 0
        for idx, (b, g) in enumerate(tc['edges']):
            if idx >= MAX_EDGES:
                break
            edge_val = create_book_edges_binary(b, g, tc['num_boys'])
            packed_edges |= (edge_val << (idx * 8))
        
        # Assign to HDL
        # We need to split if it's wider than standard python int handling in older simulators, 
        # but modern ones handle large ints. Just clamp to width if signal has a width attribute.
        dut.book_edges.value = packed_edges
        
        # 3. Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 4. Wait for done
        await wait_for_done(dut)
        
        # 5. Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
            
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            raise TestFailure(f"Test {i+1} Failed: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {i+1} Passed: Result {result}")
        
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
