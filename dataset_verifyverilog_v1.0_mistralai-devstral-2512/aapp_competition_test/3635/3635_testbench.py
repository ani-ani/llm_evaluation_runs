import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 16
MAX_N = 16
N_WIDTH = 4
RESULT_WIDTH = 5
CLK_NS = 10
MAX_CYCLES = 2000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, vals, width):
    for i, v in enumerate(vals):
        dut.arr[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_executives(dut):
    # Check if sequential module
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'rst_n')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            'desc': 'N=4, bananas=[1,2,1,2]',
            'N': 4,
            'arr': [1, 2, 1, 2],
            'expected': 3
        },
        {
            'desc': 'N=6, bananas=[6,4,2,2,2,2]',
            'N': 6,
            'arr': [6, 4, 2, 2, 2, 2],
            'expected': 3
        },
        {
            'desc': 'N=2, bananas=[1,1]',
            'N': 2,
            'arr': [1, 1],
            'expected': 2
        },
        {
            'desc': 'N=5, bananas=[1,1,1,1,1]',
            'N': 5,
            'arr': [1, 1, 1, 1, 1],
            'expected': 5
        },
        {
            'desc': 'N=3, bananas=[5,1,1]',
            'N': 3,
            'arr': [5, 1, 1],
            'expected': 1
        },
        {
            'desc': 'N=3, bananas=[1,1,5]',
            'N': 3,
            'arr': [1, 1, 5],
            'expected': 3
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"Test: {tc['desc']}")
        try:
            if is_seq:
                # Write inputs
                write_array(dut, tc['arr'], DATA_WIDTH)
                dut.N.value = tc['N']
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                result = int(dut.result.value)
            else:
                # Combinational logic
                write_array(dut, tc['arr'], DATA_WIDTH)
                dut.N.value = tc['N']
                await Timer(50, units='ns')
                result = int(dut.result.value)
            
            if result != tc['expected']:
                raise TestFailure(f"Expected {tc['expected']}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        if is_seq and failed == 0:
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")
