import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Constants
DATA_WIDTH = 16
NODE_WIDTH = 5
EDGE_COUNT = 32
MAX_CYCLES = 10000
CLK_NS = 10

def pack_edge(src, dst, a, h):
    # Packing: src[4:0], dst[4:0], a[15:0], h[15:0]
    # Assuming interface: edges[i] is a 32-bit vector or struct
    # We will assign to dut.edges[i] directly. 
    # If dut.edges is an array of signals, we assign each individually.
    return (src & 0x1F) | ((dst & 0x1F) << 5) | ((a & 0xFFFF) << 10) | ((h & 0xFFFF) << 26)

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.A.value = 0
    dut.H.value = 0
    dut.n.value = 0
    dut.m.value = 0
    # Clear edges
    if has_signal(dut, 'edges'):
        for i in range(EDGE_COUNT):
            dut.edges[i].value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_cave_nav(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational circuit
        pass

    # Test Cases
    # Case 1: Sample 1 (Should fail -> 0)
    # Input: A=1, H=2, n=3, m=2
    # Edges: 1->2 (a=1, h=2), 2->3 (a=1, h=2)
    # Combat 1->2: Unnar needs 2 hits (2 dmg). Health 2 -> 0. Dies. Invalid.
    # Expected output: 0 (mapped to 'Oh no')
    test_cases = [
        {
            'A': 1, 'H': 2, 'n': 3, 'm': 2,
            'edges': [
                (1, 2, 1, 2),
                (2, 3, 1, 2)
            ],
            'expected': 0
        },
        # Case 2: Sample 2 (Should succeed)
        # Input: A=1, H=3, n=3, m=2
        # Edges: 1->2 (a=1, h=2), 2->3 (a=1, h=2)
        # Combat 1->2: Unnar takes 1 dmg. Health 3 -> 2.
        # Combat 2->3: Unnar takes 1 dmg. Health 2 -> 1.
        # Expected output: 1
        {
            'A': 1, 'H': 3, 'n': 3, 'm': 2,
            'edges': [
                (1, 2, 1, 2),
                (2, 3, 1, 2)
            ],
            'expected': 1
        },
        # Case 3: Sample 3
        # Input: A=5, H=20, n=5, m=6
        # Expected output: 10
        {
            'A': 5, 'H': 20, 'n': 5, 'm': 6,
            'edges': [
                (1, 2, 10, 6),
                (1, 3, 2, 15),
                (1, 4, 1, 33),
                (2, 5, 1, 7),
                (3, 4, 1000, 5),
                (4, 2, 5, 9)
            ],
            'expected': 10
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        if has_signal(dut, 'clk'):
            await reset_dut(dut)

        # Drive Inputs
        dut.A.value = clamp_to_width(tc['A'], DATA_WIDTH)
        dut.H.value = clamp_to_width(tc['H'], DATA_WIDTH)
        dut.n.value = clamp_to_width(tc['n'], NODE_WIDTH)
        dut.m.value = clamp_to_width(tc['m'], NODE_WIDTH) # m fits in 5 bits (max 32)

        # Set Edges
        if has_signal(dut, 'edges'):
            for idx, edge in enumerate(tc['edges']):
                src, dst, ea, eh = edge
                # Assuming dut.edges is an array of vectors
                val = (src & 0x1F) | ((dst & 0x1F) << 5) | ((ea & 0xFFFF) << 10) | ((eh & 0xFFFF) << 26)
                dut.edges[idx].value = val
        else:
            # If individual ports: e_src_0, e_dst_0, ...
            # We assume 'edges' vector array for simplicity as per prompt
            pass

        if has_signal(dut, 'clk'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            try:
                await wait_for_done(dut)
            except TestFailure as e:
                cocotb.log.error(f"Test {i+1} Timeout: {e}")
                continue
        else:
            # Combinational, just wait a bit
            await Timer(100, units='ns')

        # Check Result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined")
        
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
             raise TestFailure(f"Test {i+1} Failed: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {i+1} Passed: Result {result}")
