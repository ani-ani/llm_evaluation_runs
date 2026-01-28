import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants
CLK_NS = 10
MAX_STATES = 4
MAX_DELEGATES = 32
TOTAL_DELEGATES = 128
DATA_WIDTH = 32
FRAC_BITS = 16
MAX_VOTES = 1 << FRAC_BITS  # 65536

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_fixed(f, frac=FRAC_BITS):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=FRAC_BITS):
    return v / (1 << frac)

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_state(dut, idx, delegate, c, f, u):
    """Load state data into DUT"""
    dut.state_valid.value = 1
    dut.state_index.value = idx
    dut.delegate_in.value = delegate
    dut.c_in.value = float_to_fixed(c)
    dut.f_in.value = float_to_fixed(f)
    dut.u_in.value = float_to_fixed(u)
    await RisingEdge(dut.clk)
    dut.state_valid.value = 0

@cocotb.test(timeout_time=10, timeout_unit='s')
async def test_election(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        # Sample 1: 3 states
        {
            'states': [
                (7, 2401, 3299, 0),
                (6, 2401, 2399, 0),
                (2, 750, 750, 99)
            ],
            'expected': 50
        },
        # Sample 2: impossible
        {
            'states': [
                (7, 100, 200, 200),
                (8, 100, 300, 200),
                (9, 100, 400, 200)
            ],
            'expected': -1  # -1 represents "impossible"
        },
        # Sample 3
        {
            'states': [
                (32, 0, 0, 20),
                (32, 0, 0, 20),
                (64, 0, 0, 41)
            ],
            'expected': 32
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Test case {tc_idx + 1}")
        
        # Reset for each test
        if has_signal(dut, 'rst_n'):
            await reset_dut(dut)
        else:
            await Timer(100, units='ns')
        
        # Load states
        total_delegates = 0
        for i, (d, c, f, u) in enumerate(tc['states']):
            total_delegates += d
            await load_state(dut, i, d, c, f, u)
        
        # Check if more states than max
        if len(tc['states']) > MAX_STATES:
            cocotb.log.warning(f"Test case has {len(tc['states'])} states > {MAX_STATES}, skipping")
            continue
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            try:
                await wait_for_done(dut)
            except TestFailure as e:
                cocotb.log.error(f"{e}")
                failed += 1
                continue
            
            # Read result
            if is_value_defined(dut.result.value):
                result = int(dut.result.value)
                
                # Convert signed value
                if result >= (1 << (DATA_WIDTH - 1)):
                    result = result - (1 << DATA_WIDTH)
                
                # Convert fixed-point to float for comparison
                result_float = fixed_to_float(result)
                expected = tc['expected']
                
                if expected == -1:
                    # Check for impossible (-1)
                    if result == -1 or result == 0xFFFFFFFF:  # -1 in two's complement
                        cocotb.log.info(f"Test {tc_idx + 1}: Correct - impossible")
                        passed += 1
                    else:
                        cocotb.log.error(f"Test {tc_idx + 1}: Expected -1, got {result}")
                        failed += 1
                else:
                    # Allow small floating point error
                    tolerance = 1.0
                    if abs(result_float - expected) <= tolerance:
                        cocotb.log.info(f"Test {tc_idx + 1}: Correct - {result_float:.0f} (expected {expected})")
                        passed += 1
                    else:
                        cocotb.log.error(f"Test {tc_idx + 1}: Expected {expected}, got {result_float:.0f}")
                        failed += 1
            else:
                cocotb.log.error(f"Test {tc_idx + 1}: Result undefined")
                failed += 1
        else:
            # Combinational logic
            await Timer(100, units='ns')
            
            if is_value_defined(dut.result.value):
                result = int(dut.result.value)
                if result >= (1 << (DATA_WIDTH - 1)):
                    result = result - (1 << DATA_WIDTH)
                
                result_float = fixed_to_float(result)
                expected = tc['expected']
                
                if expected == -1:
                    if result == -1 or result == 0xFFFFFFFF:
                        cocotb.log.info(f"Test {tc_idx + 1}: Correct - impossible")
                        passed += 1
                    else:
                        cocotb.log.error(f"Test {tc_idx + 1}: Expected -1, got {result}")
                        failed += 1
                else:
                    tolerance = 1.0
                    if abs(result_float - expected) <= tolerance:
                        cocotb.log.info(f"Test {tc_idx + 1}: Correct - {result_float:.0f}")
                        passed += 1
                    else:
                        cocotb.log.error(f"Test {tc_idx + 1}: Expected {expected}, got {result_float:.0f}")
                        failed += 1
            else:
                cocotb.log.error(f"Test {tc_idx + 1}: Result undefined")
                failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed")