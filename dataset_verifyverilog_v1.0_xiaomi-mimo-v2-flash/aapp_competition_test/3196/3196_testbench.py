import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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
    dut.start.value = 0
    dut.edges_valid.value = 0
    dut.src_node.value = 0
    dut.dst_node.value = 0
    dut.edge_count.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_edges(dut, edges, edge_count):
    """Load edges into the module. edges is list of (src, dst) tuples"""
    dut.edges_valid.value = 1
    dut.edge_count.value = clamp_to_width(edge_count, 5)
    
    for i, (src, dst) in enumerate(edges):
        dut.src_node.value = clamp_to_width(src-1, 4)  # Convert to 0-based
        dut.dst_node.value = clamp_to_width(dst-1, 4)
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
    
    dut.edges_valid.value = 0

@cocotb.test(timeout_time=10, timeout_unit='s')
async def test_bicycle_race(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            'name': 'Simple linear path',
            'edges': [(1, 2), (2, 3)],
            'source': 1,
            'dest': 3,
            'expected_result': 1,
            'expected_inf': 0
        },
        {
            'name': 'Multiple paths',
            'edges': [(1, 2), (1, 3), (2, 4), (3, 4)],
            'source': 1,
            'dest': 1,
            'expected_result': 1,
            'expected_inf': 1  # Self-loop at source
        },
        {
            'name': 'Cycle detection',
            'edges': [(1, 2), (2, 3), (3, 1), (3, 2)],
            'source': 1,
            'dest': 2,
            'expected_result': 0,
            'expected_inf': 1
        },
        {
            'name': 'No path',
            'edges': [(1, 3), (2, 4)],
            'source': 1,
            'dest': 2,
            'expected_result': 0,
            'expected_inf': 0
        },
        {
            'name': 'Large count (should modulo)',
            'edges': [(1, 3), (1, 4), (3, 5), (4, 5), (5, 6), (6, 7), (7, 2)],
            'source': 1,
            'dest': 7,
            'expected_result': 2,
            'expected_inf': 0
        }
    ]
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"\n=== Testing: {test['name']} ===")
        try:
            # Reset
            await reset_dut(dut)
            
            # Load edges
            if test['edges']:
                await load_edges(dut, test['edges'], len(test['edges']))
            else:
                dut.edges_valid.value = 1
                dut.edge_count.value = 0
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(10, units='ns')
                dut.edges_valid.value = 0
            
            # Start computation
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check results
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Check inf flag
            if has_signal(dut, 'inf_flag'):
                inf_flag = int(dut.inf_flag.value) if is_value_defined(dut.inf_flag.value) else 0
            else:
                inf_flag = 0
            
            cocotb.log.info(f"Result: {result}, Inf flag: {inf_flag}")
            
            if inf_flag != test['expected_inf']:
                raise TestFailure(f"Inf flag mismatch. Expected {test['expected_inf']}, got {inf_flag}")
            
            if not inf_flag:
                if result != test['expected_result']:
                    raise TestFailure(f"Result mismatch. Expected {test['expected_result']}, got {result}")
            
            cocotb.log.info(f"PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Summary
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed!")