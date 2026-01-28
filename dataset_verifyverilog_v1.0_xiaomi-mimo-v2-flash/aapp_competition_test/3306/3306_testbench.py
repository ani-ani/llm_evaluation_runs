import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPERS
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

# CONSTANTS
DATA_WIDTH = 32
N_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 10000

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_detector_problem(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: just set inputs and wait
        await Timer(100, units='ns')
    
    # Test cases from problem
    test_cases = [
        # (N, M, positions_list, counts_list, expected_result, description)
        (3, 4, [3, 2, 1], [1, 2, 1], 2, "Sample 1: positions 3,2,1 with counts 1,2,1"),
        (2, 3, [1, 2], [23, 17], 23, "Sample 2: positions 1,2 with counts 23,17"),
        (3, 9, [7, 8, 3], [2, 3, 4], 5, "Sample 3: positions 7,8,3 with counts 2,3,4"),
        (1, 100, [50], [42], 42, "Single detector test"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, M, positions, counts, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Reset for sequential
            if is_seq:
                await reset_dut(dut)
            
            # Set N and M
            if has_signal(dut, 'N_in'):
                dut.N_in.value = clamp_to_width(N, N_WIDTH)
            if has_signal(dut, 'M_in'):
                dut.M_in.value = clamp_to_width(M, DATA_WIDTH)
            
            # Set positions and counts
            # For arrays: individual element assignment
            for j in range(N):
                if has_signal(dut, f'P_i_{j}'):
                    getattr(dut, f'P_i_{j}').value = clamp_to_width(positions[j], DATA_WIDTH)
                if has_signal(dut, f'C_i_{j}'):
                    getattr(dut, f'C_i_{j}').value = clamp_to_width(counts[j], DATA_WIDTH)
                
                # For array access style
                if has_signal(dut, 'P_i'):
                    dut.P_i[j].value = clamp_to_width(positions[j], DATA_WIDTH)
                if has_signal(dut, 'C_i'):
                    dut.C_i[j].value = clamp_to_width(counts[j], DATA_WIDTH)
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                # Combinational: result should be immediate
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            if failed > 10:
                raise TestFailure(f"Too many failures ({failed})")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All tests passed! ({passed} tests)")