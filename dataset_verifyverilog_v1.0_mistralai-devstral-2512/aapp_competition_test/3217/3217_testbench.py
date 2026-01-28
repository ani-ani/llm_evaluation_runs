import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_DEFECTS = 256
ARRAY_BITS = 3  # 5 values need 3 bits
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def set_defects(dut, defects):
    # defects is list of (x,y,z) tuples, mapped to 5x5x5 grid
    n = len(defects)
    dut.num_defects.value = clamp_to_width(n, DATA_WIDTH)
    # Wait for internal loading if needed (simplified: just set inputs)
    for i in range(min(n, MAX_DEFECTS)):
        x, y, z = defects[i]
        dut.defect_x[i].value = clamp_to_width(x, ARRAY_BITS)
        dut.defect_y[i].value = clamp_to_width(y, ARRAY_BITS)
        dut.defect_z[i].value = clamp_to_width(z, ARRAY_BITS)
    # Fill remaining with 0
    for i in range(n, MAX_DEFECTS):
        dut.defect_x[i].value = 0
        dut.defect_y[i].value = 0
        dut.defect_z[i].value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_enclosure(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (defects_list, expected_result, description)
    # Scaling: 10x10x10 to 5x5x5 by dividing coords by 2 (floor)
    test_cases = [
        ([(0,0,0)], 6, "Single cell center"),
        ([(0,0,0), (0,0,1)], 10, "Two adjacent cells"),
        ([(0,0,0), (0,1,0), (1,0,0)], 14, "Three cells L-shape"),
        ([], 0, "No defects"),
    ]
    
    passed = 0
    failed = 0
    
    for defects, expected, desc in test_cases:
        cocotb.log.info(f"Test: {desc}")
        try:
            # Set inputs
            await set_defects(dut, defects)
            
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
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} -> {result}")
            
            # Brief reset between tests
            if is_seq and defects != test_cases[-1][0]:
                await reset_dut(dut)
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            if is_seq:
                await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")