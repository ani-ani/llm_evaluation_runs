import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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
    return min((1 << bits) - 1, max(0, int(v)))

# Reference Python implementation
def compute_min_cost(hy, ay, dy, hm, am, dm, h, a, d):
    best = 10**20
    for buy_a in range(0, 101):
        for buy_d in range(0, 101):
            eff_ay = ay + buy_a
            eff_dy = dy + buy_d
            damage_m = max(0, eff_ay - dm)
            damage_y = max(0, am - eff_dy)
            if damage_m == 0:
                continue
            turns = (hm + damage_m - 1) // damage_m
            hp_loss = turns * damage_y
            hp_needed = max(0, hp_loss - hy + 1)
            cost = buy_a * a + buy_d * d + hp_needed * h
            if cost < best:
                best = cost
    return best

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_bitcoin(dut):
    # Setup clock if it exists
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational circuit
        await Timer(100, units='ns')
    
    # Test cases: (inputs, expected_output, description)
    test_cases = [
        ([1, 2, 1, 1, 100, 1, 1, 100, 100], 99, "Sample 1: Buy 99 HP"),
        ([100, 100, 100, 1, 1, 1, 1, 1, 1], 0, "Sample 2: Already strong"),
        ([50, 80, 92, 41, 51, 56, 75, 93, 12], 0, "Test 3"),
        ([76, 63, 14, 89, 87, 35, 20, 15, 56], 915, "Test 4"),
        ([12, 59, 66, 43, 15, 16, 12, 18, 66], 0, "Test 5"),
        ([51, 89, 97, 18, 25, 63, 22, 91, 74], 0, "Test 6"),
        ([72, 16, 49, 5, 21, 84, 48, 51, 88], 3519, "Test 7"),
        ([74, 89, 5, 32, 76, 99, 62, 95, 36], 3529, "Test 8"),
        ([39, 49, 78, 14, 70, 41, 3, 33, 23], 0, "Test 9"),
        ([11, 82, 51, 90, 84, 72, 98, 98, 43], 1376, "Test 10"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inputs, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        hy, ay, dy, hm, am, dm, h, a, d = inputs
        
        # Calculate expected using reference function
        ref_result = compute_min_cost(hy, ay, dy, hm, am, dm, h, a, d)
        if expected != ref_result:
            cocotb.log.warning(f"Test case {desc} expected {expected} but ref computes {ref_result}. Using ref value.")
            expected = ref_result
        
        try:
            # Set inputs
            dut.hy.value = clamp_to_width(hy, 8)
            dut.ay.value = clamp_to_width(ay, 8)
            dut.dy.value = clamp_to_width(dy, 8)
            dut.hm.value = clamp_to_width(hm, 8)
            dut.am.value = clamp_to_width(am, 8)
            dut.dm.value = clamp_to_width(dm, 8)
            dut.h.value = clamp_to_width(h, 8)
            dut.a.value = clamp_to_width(a, 8)
            dut.d.value = clamp_to_width(d, 8)
            
            if has_signal(dut, 'clk'):
                # Sequential logic
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational logic
                await Timer(10, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: {desc} - Result {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"\nAll tests passed: {passed}/{passed + failed}")
