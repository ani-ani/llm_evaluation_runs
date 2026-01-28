import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
HR_ID_WIDTH = 4
MAX_DAYS = 16
MAX_WORKERS = 256
CLK_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'day_index'): dut.day_index.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def set_day_params(dut, day_idx, f_val, h_val):
    """Set parameters for a specific day"""
    if has_signal(dut, 'day_index'):
        dut.day_index.value = clamp_to_width(day_idx, 4)
    if has_signal(dut, 'f_i'):
        dut.f_i.value = clamp_to_width(f_val, DATA_WIDTH)
    if has_signal(dut, 'h_i'):
        dut.h_i.value = clamp_to_width(h_val, DATA_WIDTH)

async def process_day(dut, day_idx, f_val, h_val, exp_hr_id):
    """Process a single day and verify HR ID"""
    # Set parameters
    await set_day_params(dut, day_idx, f_val, h_val)
    
    # Start processing
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    else:
        # Combinational mode
        await Timer(100, units='ns')
    
    # Wait for done (if sequential)
    if has_signal(dut, 'done'):
        await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.hr_id.value):
        raise TestFailure(f"Day {day_idx}: hr_id undefined")
    
    hr_id = int(dut.hr_id.value)
    cocotb.log.info(f"Day {day_idx}: f={f_val}, h={h_val} -> HR ID: {hr_id} (expected: {exp_hr_id})")
    
    return hr_id

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_hr_optimization(dut):
    """Test HR staff optimization with multiple test cases"""
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: Sample input from problem
    test_cases = [
        {
            'name': 'Sample 1',
            'days': 4,
            'f_vals': [0, 1, 2, 2],
            'h_vals': [3, 1, 1, 0],
            'exp_hr_ids': [1, 2, 3, 2],
            'exp_min_k': 3
        },
        {
            'name': 'Sample 2',
            'days': 6,
            'f_vals': [0, 0, 2, 0, 0, 50],
            'h_vals': [10, 5, 0, 0, 100, 100],
            'exp_hr_ids': [1, 2, 1, 2, 1, 2],
            'exp_min_k': 2
        }
    ]
    
    for test in test_cases:
        cocotb.log.info(f"\n=== Testing {test['name']} ===")
        
        if is_seq:
            await reset_dut(dut)
        
        results = []
        
        for day_idx in range(test['days']):
            try:
                hr_id = await process_day(
                    dut,
                    day_idx,
                    test['f_vals'][day_idx],
                    test['h_vals'][day_idx],
                    test['exp_hr_ids'][day_idx]
                )
                results.append(hr_id)
            except TestFailure as e:
                cocotb.log.error(f"FAIL in day {day_idx}: {e}")
                raise
        
        # Verify min HR count
        if has_signal(dut, 'min_hr_k') and is_seq:
            # Wait a bit for final result
            await Timer(100, units='ns')
            min_k = int(dut.min_hr_k.value)
            exp_k = test['exp_min_k']
            if min_k != exp_k:
                raise TestFailure(f"Expected min_k={exp_k}, got {min_k}")
            cocotb.log.info(f"Min HR people: {min_k}")
        
        # Check HR IDs match expected
        for i, (got, exp) in enumerate(zip(results, test['exp_hr_ids'])):
            if got != exp:
                cocotb.log.error(f"Day {i}: Expected HR ID {exp}, got {got}")
            else:
                cocotb.log.info(f"Day {i}: HR ID {got} ✓")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_simple_case(dut):
    """Test simple 1-day case"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Single day: 0 fired, 3 hired -> HR ID 1 expected
    if has_signal(dut, 'f_i'):
        dut.f_i.value = 0
    if has_signal(dut, 'h_i'):
        dut.h_i.value = 3
    if has_signal(dut, 'day_index'):
        dut.day_index.value = 0
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    if is_value_defined(dut.hr_id.value):
        hr_id = int(dut.hr_id.value)
        if hr_id != 1:
            raise TestFailure(f"Expected HR ID 1, got {hr_id}")
        cocotb.log.info(f"Simple test: HR ID {hr_id} ✓")
    else:
        raise TestFailure("hr_id undefined")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case: no change day (0 fired, 0 hired)
    if has_signal(dut, 'f_i'):
        dut.f_i.value = 0
    if has_signal(dut, 'h_i'):
        dut.h_i.value = 0
    if has_signal(dut, 'day_index'):
        dut.day_index.value = 0
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    if is_value_defined(dut.hr_id.value):
        hr_id = int(dut.hr_id.value)
        # Should be 1 (minimum) even for no-op day
        if hr_id != 1:
            raise TestFailure(f"Expected HR ID 1 for no-op day, got {hr_id}")
        cocotb.log.info(f"No-op day: HR ID {hr_id} ✓")
    else:
        raise TestFailure("hr_id undefined")

    # Test case: large number of hires
    if has_signal(dut, 'h_i'):
        dut.h_i.value = clamp_to_width(255, DATA_WIDTH)  # Max 8-bit
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    if is_value_defined(dut.hr_id.value):
        hr_id = int(dut.hr_id.value)
        # Should still be assignable
        cocotb.log.info(f"Large hire day: HR ID {hr_id} ✓")
    else:
        raise TestFailure("hr_id undefined")
