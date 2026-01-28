import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 32
FRAC_WIDTH = 16
MAX_POINTS = 16
CLK_NS = 10
MAX_CYCLES = 200

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

def float_to_fixed(f, frac=FRAC_WIDTH):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=FRAC_WIDTH):
    return v / (1 << frac)

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_min_square_zone(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test Cases
    # Case 1: Sample Input 1 -> Points (1,0), (0,1), (1000,1)
    # Range [1,3] -> Ignore 3rd -> Side 1.0
    # Range [2,3] -> Ignore 3rd -> Side 0.0 (single point or same point logic)
    
    test_cases = [
        {
            "points": [(1.0, 0.0), (0.0, 1.0), (1000.0, 1.0)],
            "exp_side": 1.0,
            "desc": "Sample 1: Range 1-3"
        },
        {
            "points": [(0.0, 1.0), (1000.0, 1.0)],
            "exp_side": 0.0,
            "desc": "Sample 1: Range 2-3 (or 2 points colinear)"
        }
    ]

    for tc in test_cases:
        cocotb.log.info(f"Testing: {tc['desc']}")
        
        # 1. Load points
        if is_seq:
            # Assuming points come in sequentially with valid_in
            for i, (x, y) in enumerate(tc['points']):
                dut.x_in.value = float_to_fixed(x)
                dut.y_in.value = float_to_fixed(y)
                dut.idx.value = i
                dut.valid_in.value = 1
                await RisingEdge(dut.clk)
            dut.valid_in.value = 0
        else:
            # Combinational logic would need direct assignment
            # Not strictly supported by this interface spec, assuming sequential
            pass

        # 2. Start calculation
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # 3. Wait for done
            await wait_for_done(dut)
            
            # 4. Check result
            if not is_value_defined(dut.side_len.value):
                raise TestFailure("Result undefined")
            
            result_fp = int(dut.side_len.value)
            result_float = fixed_to_float(result_fp)
            exp_float = tc['exp_side']
            
            # Allow small fixed-point error (1/65536 ~ 0.000015)
            if abs(result_float - exp_float) > 0.0001:
                raise TestFailure(f"Expected {exp_float}, got {result_float}")
            
            cocotb.log.info(f"Result: {result_float} (Fixed: {result_fp})")
            
            # Reset for next test
            await reset_dut(dut)

    # Additional test: 4 points case from prompt
    # (0,0), (1000,1000), (300,300), (1,1)
    # Range [1,3]: Points (0,0), (1000,1000), (300,300)
    #   Ignore 1000,1000 -> Box (0,0)-(300,300) -> Side 300
    # Range [2,4]: Points (1000,1000), (300,300), (1,1)
    #   Ignore 1000,1000 -> Box (1,1)-(300,300) -> Side 299
    
    test_case_4 = {
        "points": [(0.0, 0.0), (1000.0, 1000.0), (300.0, 300.0), (1.0, 1.0)],
        "exp_side": 300.0,
        "desc": "Sample 2: Range 1-3"
    }
    
    cocotb.log.info(f"Testing: {test_case_4['desc']}")
    for i, (x, y) in enumerate(test_case_4['points']):
        dut.x_in.value = float_to_fixed(x)
        dut.y_in.value = float_to_fixed(y)
        dut.idx.value = i
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result_fp = int(dut.side_len.value)
    result_float = fixed_to_float(result_fp)
    exp_float = test_case_4['exp_side']
    
    if abs(result_float - exp_float) > 0.0001:
        raise TestFailure(f"Expected {exp_float}, got {result_float}")
    
    cocotb.log.info(f"Result: {result_float} (Fixed: {result_fp})")