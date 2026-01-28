import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_NODES = 16
DATA_WIDTH = 16
IDX_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

def clamp_to_width(v, width):
    max_val = (1 << width) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def string_to_indices(s):
    """Convert city name to list of byte values"""
    return [ord(c) for c in s[:20]]

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def wait_for_ready(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.ready.value) and int(dut.ready.value) == 1:
            return True
    raise TestFailure(f"Module not ready after {max_cycles} cycles")

async def load_city_mapping(dut, city_name, city_idx):
    """Load city name to index mapping"""
    await RisingEdge(dut.clk)
    dut.valid_input.value = 1
    dut.city_idx.value = clamp_to_width(city_idx, IDX_WIDTH)
    # Send city name character by character
    name_bytes = string_to_indices(city_name)
    for char_byte in name_bytes:
        dut.city_name.value = char_byte
        await RisingEdge(dut.clk)
    dut.valid_input.value = 0
    await RisingEdge(dut.clk)

async def load_route(dut, src_idx, dst_idx, cost):
    """Load route into adjacency matrix"""
    await RisingEdge(dut.clk)
    dut.valid_input.value = 1
    dut.edge_src.value = clamp_to_width(src_idx, IDX_WIDTH)
    dut.edge_dst.value = clamp_to_width(dst_idx, IDX_WIDTH)
    dut.edge_cost.value = clamp_to_width(cost, DATA_WIDTH)
    await RisingEdge(dut.clk)
    dut.valid_input.value = 0
    await RisingEdge(dut.clk)

async def load_assignment(dut, assign_idx, src_idx, dst_idx):
    """Load assignment pair"""
    await RisingEdge(dut.clk)
    dut.valid_input.value = 1
    dut.assignment_idx.value = clamp_to_width(assign_idx, 2)
    dut.assignment_src.value = clamp_to_width(src_idx, IDX_WIDTH)
    dut.assignment_dst.value = clamp_to_width(dst_idx, IDX_WIDTH)
    await RisingEdge(dut.clk)
    dut.valid_input.value = 0
    await RisingEdge(dut.clk)

async def run_test_case(dut, cities, routes, assignments, expected_cost):
    """Run a complete test case"""
    # Wait for ready
    await wait_for_ready(dut)
    
    # Load city mappings (first 16 cities)
    city_to_idx = {}
    for i, city_name in enumerate(cities[:MAX_NODES]):
        city_to_idx[city_name] = i
        await load_city_mapping(dut, city_name, i)
    
    # Load routes
    for src_name, dst_name, cost in routes:
        if src_name in city_to_idx and dst_name in city_to_idx:
            await load_route(dut, city_to_idx[src_name], city_to_idx[dst_name], cost)
    
    # Load assignments
    for i, (src_name, dst_name) in enumerate(assignments):
        if src_name in city_to_idx and dst_name in city_to_idx:
            await load_assignment(dut, i, city_to_idx[src_name], city_to_idx[dst_name])
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result signal undefined")
    
    result = int(dut.result.value)
    if result != expected_cost:
        raise TestFailure(f"Expected {expected_cost}, got {result}")
    
    cocotb.log.info(f"Test passed: result={result}")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_ticket_to_ride(dut):
    """Test the Ticket to Ride solver module"""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Sample input from problem
    cities1 = [
        "stockholm", "amsterdam", "london", "berlin", "copenhagen",
        "oslo", "helsinki", "dublin", "reykjavik", "brussels"
    ]
    routes1 = [
        ("oslo", "stockholm", 415),
        ("stockholm", "helsinki", 396),
        ("oslo", "london", 1153),
        ("oslo", "copenhagen", 485),
        ("stockholm", "copenhagen", 522),
        ("copenhagen", "berlin", 354),
        ("copenhagen", "amsterdam", 622),
        ("helsinki", "berlin", 1107),
        ("london", "amsterdam", 356),
        ("berlin", "amsterdam", 575),
        ("london", "dublin", 463),
        ("reykjavik", "dublin", 1498),
        ("reykjavik", "oslo", 1748),
        ("london", "brussels", 318),
        ("brussels", "amsterdam", 173)
    ]
    assignments1 = [
        ("stockholm", "amsterdam"),
        ("oslo", "london"),
        ("reykjavik", "dublin"),
        ("brussels", "helsinki")
    ]
    # Expected scaled cost (approx 3907 / scaling factor if any)
    # For this test, assume direct mapping
    expected1 = 3907
    
    await run_test_case(dut, cities1, routes1, assignments1, expected1)
    
    # Test case 2: Simple case
    cities2 = ["first", "second"]
    routes2 = [("first", "second", 10)]
    assignments2 = [("first", "first"), ("first", "first"), ("second", "first"), ("first", "first")]
    expected2 = 10  # Same city pairs cost 0 except one edge
    
    # Reset for second test
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await run_test_case(dut, cities2, routes2, assignments2, expected2)
    
    cocotb.log.info("All tests passed!")