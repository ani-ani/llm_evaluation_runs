import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Constants
W_WIDTH = 32
VH_WIDTH = 32
COORD_WIDTH = 32
SPEED_WIDTH = 32
MAX_GATES = 16
MAX_SKIS = 32
CLK_NS = 10
MAX_CYCLES = 500

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_ski_slalom(dut):
    # Check required signals
    required = ['clk', 'rst_n', 'start', 'W', 'vh', 'N', 'valid', 'best_speed']
    for sig in required:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {  # Example 1: Should output 2
            "W": 3, "vh": 2, "N": 3,
            "gates": [(1,1), (5,2), (1,3)],
            "S": 3, "skis": [3, 2, 1],
            "expected": 2
        },
        {  # Example 2: Impossible
            "W": 3, "vh": 2, "N": 3,
            "gates": [(1,1), (5,2), (1,3)],
            "S": 1, "skis": [3],
            "expected": None
        },
        {  # Edge case: single gate, trivial
            "W": 100, "vh": 10, "N": 1,
            "gates": [(50, 100)],
            "S": 2, "skis": [1, 10],
            "expected": 1
        },
        {  # Edge case: large coordinates, scaled
            "W": 1000, "vh": 100, "N": 2,
            "gates": [(5000, 5000), (6000, 10000)],
            "S": 1, "skis": [200],
            "expected": 200
        }
    ]
    
    passed = 0
    failed = 0
    
    for idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Test case {idx+1}: N={tc['N']}, S={tc['S']}, expected={tc['expected']}")
        
        try:
            # Set inputs
            dut.W.value = clamp_to_width(tc['W'], W_WIDTH)
            dut.vh.value = clamp_to_width(tc['vh'], VH_WIDTH)
            dut.N.value = clamp_to_width(tc['N'], 5)
            
            # Set gates
            for i in range(MAX_GATES):
                if i < tc['N']:
                    x, y = tc['gates'][i]
                    getattr(dut, f'gate_x_{i}').value = clamp_to_width(x, COORD_WIDTH)
                    getattr(dut, f'gate_y_{i}').value = clamp_to_width(y, COORD_WIDTH)
                else:
                    getattr(dut, f'gate_x_{i}').value = 0
                    getattr(dut, f'gate_y_{i}').value = 0
            
            # Set skis
            dut.S.value = clamp_to_width(tc['S'], 6)
            for i in range(MAX_SKIS):
                if i < tc['S']:
                    s_val = tc['skis'][i]
                    getattr(dut, f'skis_{i}').value = clamp_to_width(s_val, SPEED_WIDTH)
                else:
                    getattr(dut, f'skis_{i}').value = 0
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            # Check result
            if not is_value_defined(dut.best_speed.value):
                raise TestFailure("best_speed undefined")
            
            result = int(dut.best_speed.value)
            
            if tc['expected'] is None:
                # Should be 0 (impossible)
                if result != 0:
                    raise TestFailure(f"Expected 0 (impossible), got {result}")
            else:
                # Should match expected speed
                if result != tc['expected']:
                    raise TestFailure(f"Expected {tc['expected']}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Test {idx+1}")
            
            # Reset between tests
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {idx+1}: {e}")
            failed += 1
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed}/{len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")