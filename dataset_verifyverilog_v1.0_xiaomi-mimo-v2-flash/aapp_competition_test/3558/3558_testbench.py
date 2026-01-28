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
    if v < 0: v = 0
    max_val = (1 << bits) - 1
    return min(max_val, v)

# Fixed-point helpers
FIXED_FRAC = 16

def float_to_fixed(f, frac=FIXED_FRAC):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=FIXED_FRAC):
    return v / (1 << frac)

# Helper to write building data
async def write_buildings(dut, buildings, N, D_fixed):
    # Write N and D
    dut.N.value = N
    dut.D.value = D_fixed
    
    for i in range(16):  # Max 16 buildings
        if i < N:
            tx, x, h = buildings[i]
            # Scale to HDL widths: tx=1, x=32-bit, h=24-bit
            dut.buildings_tx[i].value = tx
            dut.buildings_x[i].value = clamp_to_width(x, 32)
            dut.buildings_h[i].value = clamp_to_width(h, 24)
        else:
            dut.buildings_tx[i].value = 0
            dut.buildings_x[i].value = 0
            dut.buildings_h[i].value = 0

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tv_transmitters(dut):
    # Check sequential signals
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        # Case 1: Sample input from problem
        {
            'N': 3,
            'D': 10.0,
            'buildings': [
                (1, 2.0, 6.0),  # tx at x=2, h=6
                (0, 4.0, 3.0),
                (0, 8.0, 2.0)
            ],
            'expected': 6.0,
            'desc': 'Example 1'
        },
        # Case 2: Second example
        {
            'N': 5,
            'D': 15.0,
            'buildings': [
                (0, 4.0, 3.0),
                (1, 5.0, 5.0),  # tx
                (1, 6.0, 6.0),  # tx
                (0, 9.0, 2.0),
                (0, 10.0, 3.0)
            ],
            'expected': 8.5,
            'desc': 'Example 2'
        },
        # Edge case: Single transmitter, no blocks
        {
            'N': 1,
            'D': 20.0,
            'buildings': [(1, 10.0, 5.0)],
            'expected': 20.0,
            'desc': 'Single transmitter'
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"Testing: {tc['desc']}")
        try:
            # Convert to fixed-point
            D_fixed = float_to_fixed(tc['D'])
            buildings_fixed = []
            for tx, x, h in tc['buildings']:
                buildings_fixed.append((
                    tx,
                    float_to_fixed(x),
                    float_to_fixed(h, frac=12)  # Height uses Q12.12
                ))
            
            # Write data
            await write_buildings(dut, buildings_fixed, tc['N'], D_fixed)
            
            # Trigger computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_raw = int(dut.result.value)
            result_float = fixed_to_float(result_raw)
            
            # Check with tolerance
            expected = tc['expected']
            error = abs(result_float - expected)
            
            if error > 0.001:  # 1e-3 tolerance
                raise TestFailure(f"Expected {expected:.6f}, got {result_float:.6f}, error={error:.6f}")
            
            cocotb.log.info(f"  PASS: {result_float:.6f} (expected {expected:.6f})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")