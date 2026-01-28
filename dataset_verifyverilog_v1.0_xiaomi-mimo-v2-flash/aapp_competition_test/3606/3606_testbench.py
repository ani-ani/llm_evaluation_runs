import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 256

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

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def setup_plants(dut, plants, coord_width=16):
    # plants is a list of (x, y) tuples
    for i, (x, y) in enumerate(plants):
        if i >= ARRAY_SIZE:
            break
        dut.plant_x[i].value = clamp_to_width(x, coord_width)
        dut.plant_y[i].value = clamp_to_width(y, coord_width)

def encode_directions(dir_str):
    # Pack 4-bit nibbles into 64-bit integer
    mapping = {'A': 0, 'B': 1, 'C': 2, 'D': 3}
    val = 0
    for i, char in enumerate(dir_str[:16]): # Max 16 dirs for 64 bits
        nibble = mapping.get(char, 0)
        val |= (nibble << (i * 4))
    return val

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_frog_jump(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        {
            "plants": [(5,6), (8,9), (4,13), (1,10), (7,4), (10,9), (3,7)],
            "dirs": "ACDBB",
            "expected": (7, 4)
        },
        {
            "plants": [(1,1), (2,2), (3,3), (4,4), (5,3), (6,2)],
            "dirs": "AAAAAABCCCDD",
            "expected": (5, 3)
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        # Setup inputs
        plants = tc["plants"]
        n = len(plants)
        k = len(tc["dirs"])
        
        await setup_plants(dut, plants, DATA_WIDTH)
        
        dut.dir_seq.value = encode_directions(tc["dirs"])
        dut.num_plants.value = n
        dut.num_jumps.value = k
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} failed: {e}")
            raise
            
        # Check results
        x_final = int(dut.final_x.value)
        y_final = int(dut.final_y.value)
        
        exp_x, exp_y = tc["expected"]
        
        if x_final != exp_x or y_final != exp_y:
            raise TestFailure(f"Case {i+1} failed: Expected ({exp_x}, {exp_y}), got ({x_final}, {y_final})")
            
        cocotb.log.info(f"Case {i+1} passed: ({x_final}, {y_final})")
