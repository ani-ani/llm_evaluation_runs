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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Configuration
DATA_WIDTH = 4
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 2000

async def write_array(dut, vals):
    # Clamp values to 4 bits (colors 1-16)
    for i in range(min(len(vals), ARRAY_SIZE)):
        dut.sectors[i].value = clamp_to_width(vals[i], DATA_WIDTH)

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_eq_games(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Cases
    # Input format: (sectors_list, K, C, expected_result)
    test_cases = [
        ([1, 1, 9, 9, 1, 6, 6, 39, 9], 4, 3, 2),
        ([1, 1, 1, 1, 1, 2, 2, 2, 2, 2], 2, 2, 2),
        ([1, 1, 9, 9, 1, 9, 9, 9, 9], 4, 3, 0),
    ]

    passed = 0
    failed = 0

    for i, (sectors, K, C, expected) in enumerate(test_cases):
        # Pad sectors to length 16 with 0s if necessary (assuming 0 is not a valid color)
        padded_sectors = sectors + [0] * (16 - len(sectors))
        
        cocotb.log.info(f"Test {i+1}: sectors={sectors}, K={K}, C={C}, expected={expected}")
        
        try:
            # Inputs
            dut.K_in.value = K
            dut.C_in.value = C
            await write_array(dut, padded_sectors)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=1500)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
        # Reset for next test
        await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
