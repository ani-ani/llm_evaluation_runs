import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.lock_config_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def configure_locks(dut, locks):
    dut.lock_config_valid.value = 1
    dut.lock_count.value = len(locks)
    await RisingEdge(dut.clk)
    for (a, b, x, y) in locks:
        dut.lock_from.value = a
        dut.lock_to.value = b
        dut.lock_min.value = x
        dut.lock_max.value = y
        await RisingEdge(dut.clk)
    dut.lock_config_valid.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_badge_access(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test Case 1: Sample Input 1
    # N=4, L=5, B=10
    # S=3, D=2
    # Locks: (1,2,4,7), (3,1,1,6), (3,4,7,10), (2,4,3,5), (4,2,8,9)
    locks1 = [(1, 2, 4, 7), (3, 1, 1, 6), (3, 4, 7, 10), (2, 4, 3, 5), (4, 2, 8, 9)]
    s1, d1 = 3, 2
    expected1 = 5
    
    # Wait for ready
    if has_signal(dut, 'ready'):
        for _ in range(100):
            if int(dut.ready.value) == 1: break
            await RisingEdge(dut.clk)
    
    await configure_locks(dut, locks1)
    
    # Wait a cycle after configuration
    await RisingEdge(dut.clk)
    
    # Start processing
    dut.s_room.value = s1
    dut.d_room.value = d1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut, max_cycles=70000) # Allow up to 65536 cycles
    
    # Read result
    result = int(dut.result.value)
    if result != expected1:
        raise TestFailure(f"Test 1 failed: Expected {expected1}, got {result}")
    
    # Test Case 2: Sample Input 2
    # N=4, L=5, B=9
    # S=1, D=4
    # Locks: (1,2,3,5), (1,3,6,7), (1,4,2,3), (2,4,4,6), (3,4,7,9)
    locks2 = [(1, 2, 3, 5), (1, 3, 6, 7), (1, 4, 2, 3), (2, 4, 4, 6), (3, 4, 7, 9)]
    s2, d2 = 1, 4
    expected2 = 5
    
    # Reset for next test
    await reset_dut(dut)
    
    if has_signal(dut, 'ready'):
        for _ in range(100):
            if int(dut.ready.value) == 1: break
            await RisingEdge(dut.clk)
            
    await configure_locks(dut, locks2)
    await RisingEdge(dut.clk)
    
    dut.s_room.value = s2
    dut.d_room.value = d2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut, max_cycles=70000)
    
    result = int(dut.result.value)
    if result != expected2:
        raise TestFailure(f"Test 2 failed: Expected {expected2}, got {result}")
    
    cocotb.log.info("All tests passed!")
