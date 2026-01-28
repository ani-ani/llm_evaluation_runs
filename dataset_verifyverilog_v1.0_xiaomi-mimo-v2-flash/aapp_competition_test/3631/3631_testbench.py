import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
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

# Fixed-point helpers
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_beacon_bfs(dut):
    # Setup clock
    clk_period = 10  # ns
    cocotb.start_soon(Clock(dut.clk, clk_period, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Example from problem
    # 6 beacons, 3 mountains
    n = 6
    m = 3
    beacons = [
        (1, 8), (5, 4), (7, 7), (9, 2), (16, 6), (17, 10)
    ]
    mountains = [
        (4, 7, 2), (6, 3, 1), (12, 6, 3)
    ]
    expected_result = 2
    
    # Load inputs
    dut.n.value = n
    dut.m.value = m
    
    # Load beacons (using direct port access)
    for i in range(16):
        if i < n:
            bx, by = beacons[i]
        else:
            bx, by = 0, 0
        if has_signal(dut, f'beacon_x_{i}'):
            getattr(dut, f'beacon_x_{i}').value = clamp_to_width(bx, 16)
            getattr(dut, f'beacon_y_{i}').value = clamp_to_width(by, 16)
        elif has_signal(dut, f'beacon_x'):
            dut.beacon_x[i].value = clamp_to_width(bx, 16)
            dut.beacon_y[i].value = clamp_to_width(by, 16)
    
    # Load mountains
    for i in range(16):
        if i < m:
            mx, my, mr = mountains[i]
        else:
            mx, my, mr = 0, 0, 0
        if has_signal(dut, f'mountain_x_{i}'):
            getattr(dut, f'mountain_x_{i}').value = clamp_to_width(mx, 16)
            getattr(dut, f'mountain_y_{i}').value = clamp_to_width(my, 16)
            getattr(dut, f'mountain_r_{i}').value = clamp_to_width(mr, 16)
        elif has_signal(dut, f'mountain_x'):
            dut.mountain_x[i].value = clamp_to_width(mx, 16)
            dut.mountain_y[i].value = clamp_to_width(my, 16)
            dut.mountain_r[i].value = clamp_to_width(mr, 16)
    
    # Wait for inputs to settle
    await Timer(100, units='ns')
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.result.value)
    cocotb.log.info(f"Test 1 - Result: {result}, Expected: {expected_result}")
    
    if result != expected_result:
        raise TestFailure(f"Expected {expected_result}, got {result}")
    
    # Test case 2: Square formation, should be 1 component
    await reset_dut(dut)
    
    n2 = 4
    m2 = 4
    beacons2 = [(0, 4), (8, 4), (4, 0), (4, 8)]
    mountains2 = [(2, 2, 1), (6, 2, 1), (2, 6, 1), (6, 6, 1)]
    expected_result2 = 1
    
    dut.n.value = n2
    dut.m.value = m2
    
    for i in range(16):
        if i < n2:
            bx, by = beacons2[i]
        else:
            bx, by = 0, 0
        if has_signal(dut, f'beacon_x_{i}'):
            getattr(dut, f'beacon_x_{i}').value = clamp_to_width(bx, 16)
            getattr(dut, f'beacon_y_{i}').value = clamp_to_width(by, 16)
        elif has_signal(dut, f'beacon_x'):
            dut.beacon_x[i].value = clamp_to_width(bx, 16)
            dut.beacon_y[i].value = clamp_to_width(by, 16)
    
    for i in range(16):
        if i < m2:
            mx, my, mr = mountains2[i]
        else:
            mx, my, mr = 0, 0, 0
        if has_signal(dut, f'mountain_x_{i}'):
            getattr(dut, f'mountain_x_{i}').value = clamp_to_width(mx, 16)
            getattr(dut, f'mountain_y_{i}').value = clamp_to_width(my, 16)
            getattr(dut, f'mountain_r_{i}').value = clamp_to_width(mr, 16)
        elif has_signal(dut, f'mountain_x'):
            dut.mountain_x[i].value = clamp_to_width(mx, 16)
            dut.mountain_y[i].value = clamp_to_width(my, 16)
            dut.mountain_r[i].value = clamp_to_width(mr, 16)
    
    await Timer(100, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result2 = int(dut.result.value)
    cocotb.log.info(f"Test 2 - Result: {result2}, Expected: {expected_result2}")
    
    if result2 != expected_result2:
        raise TestFailure(f"Expected {expected_result2}, got {result2}")
    
    cocotb.log.info("All tests passed!")
