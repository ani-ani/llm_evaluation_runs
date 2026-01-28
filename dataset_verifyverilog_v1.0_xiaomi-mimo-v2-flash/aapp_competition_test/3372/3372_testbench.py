import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 4
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 300

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def configure_airport(dut, idx, type_char, lst):
    """Configure airport idx with type and list lst"""
    # Set type (0=N, 1=C)
    type_bit = 1 if type_char == 'C' else 0
    getattr(dut, f'type_{idx}').value = type_bit
    # Set length
    getattr(dut, f'len_{idx}').value = clamp_to_width(len(lst), 4)
    # Pack list into 64-bit (16 airports * 4 bits each)
    packed = 0
    for i, val in enumerate(lst):
        packed |= (clamp_to_width(val, 4) << (i*4))
    getattr(dut, f'list_{idx}').value = packed

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_flight_bfs(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test case 1: Impossible (sample input 1)
    # 4 0 1
    # N 1 2  (airport 0 -> [2])
    # C 1 2  (airport 1 -> all except [2], so -> [0,3] since N=4)
    # N 1 3  (airport 2 -> [3])
    # C 1 1  (airport 3 -> all except [1], so -> [0,2])
    # Path 0->1: 0->2->3->? No edge to 1. Impossible.
    dut.s.value = 0
    dut.t.value = 1
    await configure_airport(dut, 0, 'N', [2])
    await configure_airport(dut, 1, 'C', [2])  # Outgoing: 0,3
    await configure_airport(dut, 2, 'N', [3])
    await configure_airport(dut, 3, 'C', [1])  # Outgoing: 0,2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    if not is_value_defined(dut.done.value) or int(dut.done.value)!=1:
        raise TestFailure("Done not asserted")
    
    if not is_value_defined(dut.valid.value):
        raise TestFailure("Valid undefined")
    
    if int(dut.valid.value) == 1:
        raise TestFailure(f"Test 1: Expected no path (valid=0), got valid=1, result={safe_int(dut.result.value)}")
    
    cocotb.log.info("Test 1 passed: Correctly identified no path")
    
    # Reset for test case 2
    await reset_dut(dut)
    
    # Test case 2: Path exists (sample input 2)
    # 4 0 1
    # N 1 2  (airport 0 -> [2])
    # C 1 2  (airport 1 -> [0,3])
    # N 1 3  (airport 2 -> [3])
    # C 1 0  (airport 3 -> all except [0], so -> [1,2])
    # Path: 0->2->3->1 (3 flights)
    dut.s.value = 0
    dut.t.value = 1
    await configure_airport(dut, 0, 'N', [2])
    await configure_airport(dut, 1, 'C', [2])  # Outgoing: 0,3
    await configure_airport(dut, 2, 'N', [3])
    await configure_airport(dut, 3, 'C', [0])  # Outgoing: 1,2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    if not is_value_defined(dut.done.value) or int(dut.done.value)!=1:
        raise TestFailure("Done not asserted")
    
    if not is_value_defined(dut.valid.value):
        raise TestFailure("Valid undefined")
    
    if int(dut.valid.value) == 0:
        raise TestFailure("Test 2: Expected path (valid=1), got valid=0")
    
    result = int(dut.result.value)
    expected = 3
    if result != expected:
        raise TestFailure(f"Test 2: Expected {expected}, got {result}")
    
    cocotb.log.info(f"Test 2 passed: Result={result}")
    
    # Additional test: Direct flight
    await reset_dut(dut)
    dut.s.value = 0
    dut.t.value = 1
    await configure_airport(dut, 0, 'N', [1])
    for i in range(1, 16):
        await configure_airport(dut, i, 'N', [])
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    if int(dut.valid.value) == 0:
        raise TestFailure("Test 3: Expected direct path")
    result = int(dut.result.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Test 3: Expected {expected}, got {result}")
    cocotb.log.info(f"Test 3 passed: Result={result}")
