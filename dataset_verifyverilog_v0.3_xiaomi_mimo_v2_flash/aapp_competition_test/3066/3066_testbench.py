import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 4
ARRAY_SIZE = 16
MAX_COLOR = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits - 1))), min((1 << (bits - 1)) - 1, value)), bits)
    return min(max_val, max(0, value))

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
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tape_art_solver(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        {"n": 6, "colors": [1, 2, 3, 3, 2, 1], "possible": True, 
         "expected": [(1, 6, 1), (2, 5, 2), (3, 4, 3)], "desc": "Nested"},
        {"n": 4, "colors": [1, 2, 1, 2], "possible": False, 
         "expected": [], "desc": "Overlapping non-nested"},
        {"n": 10, "colors": [3, 3, 3, 5, 4, 2, 4, 4, 5, 1], "possible": True,
         "expected": [(4, 9, 5), (5, 8, 4), (10, 10, 1), (6, 6, 2), (1, 3, 3)], "desc": "Complex"},
    ]
    
    passed = 0
    for test in test_cases:
        dut._log.info(f"Test: {test['desc']}")
        dut.n.value = test['n']
        for i in range(ARRAY_SIZE):
            dut.colors[i].value = clamp_to_width(test['colors'][i], DATA_WIDTH) if i < test['n'] else 0
        
        await start_computation(dut)
        await wait_for_done(dut)
        
        if test['possible']:
            if dut.impossible.value:
                raise TestFailure(f"Expected possible but got IMPOSSIBLE")
            
            num_inst = int(dut.num_instructions.value)
            if num_inst != len(test['expected']):
                raise TestFailure(f"Expected {len(test['expected'])} instructions, got {num_inst}")
            
            instructions = []
            for i in range(num_inst):
                if not is_value_defined(dut.inst_valid[i].value) or int(dut.inst_valid[i].value) != 1:
                    raise TestFailure(f"Instruction {i} invalid")
                instructions.append((int(dut.inst_l[i].value), int(dut.inst_r[i].value), int(dut.inst_c[i].value)))
            
            for exp in test['expected']:
                if exp not in instructions:
                    raise TestFailure(f"Expected instruction {exp} not found")
            
            dut._log.info(f"  PASS: {num_inst} instructions verified")
            passed += 1
        else:
            if not dut.impossible.value:
                raise TestFailure(f"Expected IMPOSSIBLE")
            dut._log.info("  PASS: Correctly IMPOSSIBLE")
            passed += 1
    
    dut._log.info(f"Results: {passed}/{len(test_cases)} passed")
    if passed != len(test_cases):
        raise TestFailure(f"{len(test_cases) - passed} tests failed")