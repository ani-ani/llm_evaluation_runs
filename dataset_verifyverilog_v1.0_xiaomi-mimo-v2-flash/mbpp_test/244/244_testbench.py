import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_next_perfect_square(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (N, expected_next_square)
    test_cases = [
        (35, 36),
        (6, 9),
        (9, 16),
        (0, 1),
        (1, 4),
        (15, 16),
        (24, 25),
        (48, 49),
        (63, 64),
        (80, 81),
        (255, 256),  # sqrt(255)=15, 16^2=256
        (100, 121),  # sqrt(100)=10, 11^2=121
        (120, 121),  # sqrt(120)=10, 11^2=121
        (121, 144),  # sqrt(121)=11, 12^2=144
        (254, 256),  # sqrt(254)=15, 16^2=256
        (256, 289),  # sqrt(256)=16, 17^2=289
        (400, 441),  # sqrt(400)=20, 21^2=441
        (483, 484),  # sqrt(483)=21, 22^2=484
        (484, 529),  # sqrt(484)=22, 23^2=529
        (575, 576),  # sqrt(575)=23, 24^2=576
        (576, 625),  # sqrt(576)=24, 25^2=625
    ]
    
    passed = failed = 0
    
    for i, (N, expected) in enumerate(test_cases):
        # Skip if result > 65535
        if expected > 65535:
            cocotb.log.info(f"Test {i+1} skipped: expected {expected} > 65535")
            continue
            
        cocotb.log.info(f"Test {i+1}: N={N}, Expected={expected}")
        try:
            # Set input
            dut.N.value = clamp_to_width(N, DATA_WIDTH)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
                
            passed += 1
            cocotb.log.info(f"PASS: N={N} -> {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed} total")