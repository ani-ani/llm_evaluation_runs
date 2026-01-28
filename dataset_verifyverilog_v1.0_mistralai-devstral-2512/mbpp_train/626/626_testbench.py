import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, CLK_NS, MAX_CYCLES = 8, 10, 100

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

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

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_triangle_area(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem + additional
    test_cases = [
        (0, 0, "radius=0, area=0"),
        (1, 128, "radius=1, area=0.5×256=128"),
        (2, 512, "radius=2, area=2×256=512"),
        (4, 2048, "radius=4, area=8×256=2048"),
        (10, 12800, "radius=10, area=50×256=12800"),
        (100, 128000, "radius=100, area=5000×256=128000"),
        (255, 32641, "radius=255, area=32640.5×256≈32641"),
    ]
    
    passed = failed = 0
    
    for i, (radius, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Clamp radius to 8 bits
            radius_clamped = clamp_to_width(radius, DATA_WIDTH)
            dut.radius.value = radius_clamped
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.area_out.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.area_out.value)
            # For Q8.8 format, check with small tolerance for rounding
            if abs(result - expected) > 1:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            cocotb.log.info(f"  Result: {result} (expected {expected})")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Additional random test
    cocotb.log.info("Testing random values...")
    for _ in range(10):
        r = random.randint(0, 255)
        expected = (r * r) // 2
        expected_q8_8 = expected * 256
        
        dut.radius.value = r
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        if not is_value_defined(dut.area_out.value):
            raise TestFailure("Result undefined")
        
        result = int(dut.area_out.value)
        if abs(result - expected_q8_8) > 1:
            raise TestFailure(f"Random test failed: r={r}, expected {expected_q8_8}, got {result}")
        passed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed! {passed} total tests")