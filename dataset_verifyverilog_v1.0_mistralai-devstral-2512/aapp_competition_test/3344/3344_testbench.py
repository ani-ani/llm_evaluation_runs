import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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
    return min((1 << bits) - 1, max(0, int(v)))

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

# Scaling constants for fixed-point Q10.6 (10 integer, 6 fractional bits)
SCALE = 64  # 2^6
MAX_POS = 1000 * SCALE  # 64000
MAX_L = 16 * SCALE  # 1024
MAX_V = 10 * SCALE  # 640
MIN_V = 0.1 * SCALE  # 6.4 (7 rounded)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_luggage(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: adapt to scaled inputs
    test_cases = [
        # Case 1: N=2, L=3, pos=[0.00, 2.00] -> output 2
        {
            'N': 2, 'L': 3, 'pos': [0.00, 2.00],
            'expected_v': 2.0, 'expected_no_fika': False,
            'desc': 'Example 1: 2 bags, L=3'
        },
        # Case 2: N=3, L=4, pos=[0.05, 1.00, 3.50] -> output 0.5
        {
            'N': 3, 'L': 4, 'pos': [0.05, 1.00, 3.50],
            'expected_v': 0.5, 'expected_no_fika': False,
            'desc': 'Example 2: 3 bags, L=4'
        },
        # Case 3: No valid speed (densely packed)
        {
            'N': 2, 'L': 1, 'pos': [0.00, 0.50],
            'expected_v': None, 'expected_no_fika': True,
            'desc': 'No fika case: distances too close'
        }
    ]
    
    passed = failed = 0
    
    for tc in test_cases:
        desc = tc['desc']
        N = tc['N']
        L = tc['L']
        pos = tc['pos']
        
        # Scale inputs
        L_scaled = int(L * SCALE)
        pos_scaled = [int(p * SCALE) for p in pos]
        
        # Pad positions to 8
        while len(pos_scaled) < 8:
            pos_scaled.append(0)
        
        cocotb.log.info(f"Test: {desc} (N={N}, L={L})")
        
        try:
            if is_seq:
                # Set inputs
                dut.N_val.value = N
                dut.L_val.value = L_scaled
                for i in range(8):
                    getattr(dut, f'pos_{i}').value = pos_scaled[i]
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                # Read results
                valid = int(dut.valid.value)
                if valid != 1:
                    raise TestFailure("Valid not asserted")
                
                result = int(dut.result.value)
                no_fika = int(dut.no_fika.value)
                
                # Check expectations
                if tc['expected_no_fika']:
                    if no_fika != 1:
                        raise TestFailure(f"Expected no_fika=1, got {no_fika}")
                    cocotb.log.info("  PASS: Correctly reported no fika")
                else:
                    if no_fika != 0:
                        raise TestFailure(f"Expected no_fika=0, got {no_fika}")
                    
                    # Convert result back to float
                    result_float = result / SCALE
                    expected = tc['expected_v']
                    
                    # Allow small error
                    error = abs(result_float - expected)
                    if error > 1e-9:
                        raise TestFailure(f"Expected v={expected}, got {result_float}, error={error}")
                    cocotb.log.info(f"  PASS: v={result_float} (expected {expected})")
                
                passed += 1
            else:
                # Combinational: wait and read
                await Timer(100, units='ns')
                # Similar checks, but assume sequential for simplicity
                raise TestFailure("Testbench requires sequential module")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    cocotb.log.info(f"All {passed} tests passed")
