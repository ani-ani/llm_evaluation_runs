import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Parameters
DATA_WIDTH = 8
NUM_NODES = 8
MAX_EDGES = 16
CLK_NS = 10
MAX_CYCLES = 5000

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
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_edge(dut, u, v, cap):
    dut.edge_valid.value = 1
    dut.edge_u.value = u
    dut.edge_v.value = v
    dut.edge_cap.value = clamp_to_width(cap, DATA_WIDTH)
    await RisingEdge(dut.clk)
    dut.edge_valid.value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_max_flow(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'rst_n') and has_signal(dut, 'done')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Sequential signals (clk, rst_n, done) not found")
    
    # Test cases (scaled down capacities)
    test_cases = [
        # Simple flow: 2 paths, capacity 1 each
        {
            'desc': 'Simple 4-node flow',
            'src': 0, 'sink': 3,
            'edges': [(0,1,2), (1,2,1), (1,3,1), (0,2,1), (2,3,2)],
            'expected_flow': 3
        },
        # Single edge large capacity
        {
            'desc': 'Single edge',
            'src': 0, 'sink': 1,
            'edges': [(0,1,100)],
            'expected_flow': 100
        },
        # No path
        {
            'desc': 'No path from src to sink',
            'src': 1, 'sink': 0,
            'edges': [(0,1,100)],
            'expected_flow': 0
        }
    ]
    
    passed = 0
    failed = 0
    
    for idx, tc in enumerate(test_cases):
        cocotb.log.info(f"\nTest {idx+1}: {tc['desc']}")
        try:
            # Reset again before test
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
            
            # Load source and sink
            if has_signal(dut, 'src'):
                dut.src.value = tc['src']
            if has_signal(dut, 'sink'):
                dut.sink.value = tc['sink']
            
            # Load edges
            for u, v, cap in tc['edges']:
                await load_edge(dut, u, v, cap)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            expected = tc['expected_flow']
            
            if result != expected:
                raise TestFailure(f"Expected max flow {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: Got expected flow {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    cocotb.log.info(f"\n=== Results: {passed} passed, {failed} failed ===")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")