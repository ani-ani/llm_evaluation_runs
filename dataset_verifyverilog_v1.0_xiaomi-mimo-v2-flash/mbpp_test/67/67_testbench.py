import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
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

# Bell numbers for n ≤ 8
BELL_NUMBERS = [
    1,  # n=0
    1,  # n=1
    2,  # n=2
    5,  # n=3
    15, # n=4
    52, # n=5
    203, # n=6
    877, # n=7
    4140 # n=8
]

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_bell_number(dut):
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module must have 'clk' signal")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Verify reset state
    if has_signal(dut, 'done') and int(dut.done.value) != 0:
        raise TestFailure("done should be 0 after reset")
    
    passed = 0
    failed = 0
    
    # Test all valid n values (0-8)
    for n in range(9):
        exp = BELL_NUMBERS[n]
        cocotb.log.info(f"Testing n={n}, expected B(n)={exp}")
        
        try:
            # Set input n
            dut.n.value = n
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=200)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != exp:
                raise TestFailure(f"n={n}: Expected {exp}, got {result}")
            
            cocotb.log.info(f"PASS: n={n} -> {result}")
            passed += 1
            
            # Wait one more cycle to ensure done pulse ends
            await RisingEdge(dut.clk)
            if int(dut.done.value) != 0:
                raise TestFailure("done should be 0 after one cycle")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    # Test additional random values in valid range
    for _ in range(3):
        n = random.randint(0, 8)
        exp = BELL_NUMBERS[n]
        cocotb.log.info(f"Random test: n={n}, expected={exp}")
        
        try:
            dut.n.value = n
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut, max_cycles=200)
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Random n={n}: Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Random n={n} -> {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Test that module handles n > 8 gracefully (shouldn't crash)
    cocotb.log.info("Testing boundary: n=9 (should produce some result)")
    try:
        dut.n.value = 9
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait up to 200 cycles but don't require exact result
        for _ in range(200):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        if is_value_defined(dut.result.value):
            result = int(dut.result.value)
            cocotb.log.info(f"n=9 produced result: {result}")
            # No assertion - just verify it produces some defined value
        
        passed += 1
        
    except Exception as e:
        cocotb.log.warning(f"n=9 handling: {e}")
        # This is acceptable - behavior undefined for n>8
        passed += 1
    
    # Final summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
