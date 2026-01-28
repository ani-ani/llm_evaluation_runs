import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 16
ADDR_WIDTH = 4  # For 0-15
MAX_BLOCKS = 15
MAX_BUILDINGS = 15
CLK_NS = 10
TIMEOUT_CYCLES = 60000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if v < 0: v = 0
    max_val = (1 << bits) - 1
    return min(max_val, v)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def write_array_packed(dut, prefix, values, width):
    """Handles signals like block_heights_0, block_heights_1..."""
    for i, v in enumerate(values):
        if i < MAX_BLOCKS:  # Safety limit
            sig_name = f"{prefix}_{i}"
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = clamp_to_width(v, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=TIMEOUT_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_done.value) and int(dut.result_done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_skyline_builder(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Cases
    test_cases = [
        {
            "blocks": [3, 3, 2, 1],
            "buildings": [3, 3, 3],
            "expected_valid": True,
            "description": "Sample 1: 4 blocks, 3 buildings"
        },
        {
            "blocks": [3, 3, 2, 2],
            "buildings": [6, 3],
            "expected_valid": False,
            "description": "Sample 2: Impossible sum"
        },
        {
            "blocks": [5, 4, 3, 6, 1, 2, 2],
            "buildings": [4, 11, 4],
            "expected_valid": True,
            "description": "Sample 3: 7 blocks"
        }
    ]

    for tc in test_cases:
        cocotb.log.info(f"Running test: {tc['description']}")
        
        # Reset for each test case
        await reset_dut(dut)
        
        # Write Inputs
        N = len(tc['blocks'])
        S = len(tc['buildings'])
        
        # Assuming flattened inputs or indexed inputs. 
        # Based on spec, we expect signals like block_heights_0, block_heights_1...
        write_array_packed(dut, 'block_heights', tc['blocks'], DATA_WIDTH)
        write_array_packed(dut, 'building_targets', tc['buildings'], DATA_WIDTH)
        
        if has_signal(dut, 'N_val'):
            dut.N_val.value = N
        if has_signal(dut, 'S_val'):
            dut.S_val.value = S
            
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for Done
        await wait_for_done(dut)
        
        # Check Results
        if not is_value_defined(dut.result_valid.value):
            raise TestFailure("result_valid signal is undefined")
            
        result_valid = int(dut.result_valid.value)
        
        if tc['expected_valid']:
            if result_valid != 1:
                raise TestFailure(f"Expected valid=1, got {result_valid} for {tc['description']}")
            
            # Verify internal consistency (optional but good)
            # Since we don't have direct access to the partition map in this simple spec,
            # we rely on the module asserting validity. 
            # A more advanced testbench would check the output against expected partition masks.
            
            cocotb.log.info(f"PASS: {tc['description']} - Valid partition found")
        else:
            if result_valid != 0:
                raise TestFailure(f"Expected valid=0, got {result_valid} for {tc['description']}")
            cocotb.log.info(f"PASS: {tc['description']} - Correctly detected impossibility")
