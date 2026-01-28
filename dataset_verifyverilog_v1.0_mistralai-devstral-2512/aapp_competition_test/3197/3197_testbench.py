import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

def pack_array(vals, bits=8):
    """Pack a list of integers into a single integer."""
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_participants(dut):
    # Setup
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases: (n, k, edges_list, expected_result)
    # edges_list is 1-based input from problem statement
    test_cases = [
        (4, 4, [1, 2, 3, 4], 4),
        (12, 3, [2, 3, 4, 5, 6, 7, 4, 7, 8, 8, 12, 12], 2),
        (5, 4, [2, 3, 1, 5, 4], 3)
    ]

    for n, k, edges_1based, expected in test_cases:
        cocotb.log.info(f"Running test: n={n}, k={k}, expected={expected}")
        
        # Convert 1-based to 0-based for hardware
        edges_0based = [x - 1 for x in edges_1based]
        
        # Pad to 16 elements for the 64-bit input
        while len(edges_0based) < 16:
            edges_0based.append(0)
        
        # Pack into 64-bit value (4 bits per element)
        packed_edges = pack_array(edges_0based, bits=4)
        
        # Drive inputs
        dut.n.value = n
        dut.k.value = k
        dut.edges_flat.value = packed_edges
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test failed for n={n}, k={k}. Expected {expected}, got {result}")
        
        cocotb.log.info(f"Success: Got {result}")
        
        # Small delay between tests
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)
