import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
MAX_N = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if v < 0:
        v = (1 << bits) + v
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def pack_string(s):
    """Pack string into 16-bit binary (0='(', 1=')')"""
    packed = 0
    for i, c in enumerate(s):
        if c == ')':
            packed |= (1 << i)
    return packed

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_balanced_string(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: n=4, k=1, str="((()", costs=[480,617,-570,928]
    # Expected: 480 (minimum cost to make impossible)
    n = 4
    k = 1
    s = "((()"
    costs = [480, 617, -570, 928]
    
    # Scale costs (divide by 8 for 8-bit range)
    scaled_costs = [c // 8 for c in costs]
    
    cocotb.log.info(f"Test 1: n={n}, k={k}, str={s}, costs={costs}")
    
    # Set inputs
    if is_seq:
        dut.n.value = n
        dut.k.value = k
        dut.str.value = pack_string(s)
        
        # Set costs
        for i in range(MAX_N):
            if i < n:
                dut.cost[i].value = clamp_to_width(scaled_costs[i], 8)
            else:
                dut.cost[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result_val = int(dut.result.value)
        result = to_signed(result_val, 16)
        
        # Check result (scaled back)
        expected = 480 // 8  # Scaled
        
        if abs(result - expected) > 2:  # Allow small scaling error
            raise TestFailure(f"Expected ~{expected}, got {result}")
        
        cocotb.log.info(f"Test 1 passed: result={result_val}")
    else:
        await Timer(100, units='ns')

    # Test case 2: n=4, k=3, str=")()(", costs=[-532,870,617,905]
    # Expected: ? (impossible to make impossible)
    n2 = 4
    k2 = 3
    s2 = ")()("
    costs2 = [-532, 870, 617, 905]
    
    scaled_costs2 = [c // 8 for c in costs2]
    
    cocotb.log.info(f"Test 2: n={n2}, k={k2}, str={s2}, costs={costs2}")
    
    if is_seq:
        dut.n.value = n2
        dut.k.value = k2
        dut.str.value = pack_string(s2)
        
        for i in range(MAX_N):
            if i < n2:
                dut.cost[i].value = clamp_to_width(scaled_costs2[i], 8)
            else:
                dut.cost[i].value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result_val = int(dut.result.value)
        result = to_signed(result_val, 16)
        
        # Check for impossible flag (0x8000)
        impossible = has_signal(dut, 'impossible') and int(dut.impossible.value) == 1
        
        if result == -32768 or impossible:
            cocotb.log.info("Test 2 passed: correctly identified impossible case")
        else:
            raise TestFailure(f"Expected '?' (impossible), got {result}")
    else:
        await Timer(100, units='ns')

    # Additional test: simple balanced string
    n3 = 2
    k3 = 0
    s3 = "()"
    costs3 = [10, 20]
    
    scaled_costs3 = [c // 8 for c in costs3]
    
    cocotb.log.info(f"Test 3: n={n3}, k={k3}, str={s3}")
    
    if is_seq:
        dut.n.value = n3
        dut.k.value = k3
        dut.str.value = pack_string(s3)
        
        for i in range(MAX_N):
            if i < n3:
                dut.cost[i].value = clamp_to_width(scaled_costs3[i], 8)
            else:
                dut.cost[i].value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result_val = int(dut.result.value)
        result = to_signed(result_val, 16)
        
        # Should find minimum cost to make unbalanced (flip one char)
        # Flipping '(' at pos 0: cost 10, makes ")("
        # Flipping ')' at pos 1: cost 20, makes "(("
        # Either makes unbalanced, minimum cost is 10
        expected_min = 10 // 8
        
        if abs(result - expected_min) > 2:
            raise TestFailure(f"Expected ~{expected_min}, got {result}")
        
        cocotb.log.info(f"Test 3 passed: result={result_val}")
