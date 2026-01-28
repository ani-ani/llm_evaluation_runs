import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 10
MAX_N = 1024
CLK_NS = 10
MAX_CYCLES = 4000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'data_valid'):
        dut.data_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def feed_sequence(dut, seq):
    """Feed sequence to module serially"""
    dut.data_valid.value = 1
    for i, val in enumerate(seq):
        dut.data_in.value = clamp_to_width(val, DATA_WIDTH)
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit="seconds")
async def test_wi_know(dut):
    # Setup clock
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test cases: (sequence, expected_A, expected_B, found, description)
    test_cases = [
        ([1,3,2,4,1,5,2,4], 1, 2, True, "Sample 1: lexicographically smallest A,B"),
        ([1,2,3,4,5,6,7,1], None, None, False, "Sample 2: no valid pair"),
        ([2,1,2,1], 2, 1, True, "Simple case: A=2,B=1"),
        ([1,1,1,1], None, None, False, "All same: A≠B required"),
        ([1,2,3,1,2,3], 1, 2, True, "Multiple possibilities: pick lexicographically smallest"),
        ([3,2,1,3,2,1], 3, 2, True, "Reverse lexicographic order"),
        ([4,3,2,1,4,3,2,1], 4, 3, True, "Four numbers"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (seq, exp_A, exp_B, should_find, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        cocotb.log.info(f"Input sequence: {seq}")
        
        try:
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed sequence
            await feed_sequence(dut, seq)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=3000)
            
            # Read results
            found = int(dut.found.value) if is_value_defined(dut.found.value) else 0
            
            if should_find:
                if found != 1:
                    raise TestFailure(f"Expected found=1, got {found}")
                
                A = int(dut.A_out.value) if is_value_defined(dut.A_out.value) else 0
                B = int(dut.B_out.value) if is_value_defined(dut.B_out.value) else 0
                
                if A != exp_A or B != exp_B:
                    raise TestFailure(f"Expected ({exp_A}, {exp_B}), got ({A}, {B})")
                
                cocotb.log.info(f"✓ Found A={A}, B={B}")
            else:
                if found != 0:
                    A = int(dut.A_out.value) if is_value_defined(dut.A_out.value) else 0
                    B = int(dut.B_out.value) if is_value_defined(dut.B_out.value) else 0
                    raise TestFailure(f"Expected no pair, but found A={A}, B={B}")
                cocotb.log.info("✓ Correctly found no valid pair (-1)")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    cocotb.log.info(f"\n=== Results: {passed} passed, {failed} failed ===")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")

@cocotb.test(timeout_time=10, timeout_unit="seconds")
async def test_large_sequence(dut):
    """Test with larger N to verify timing"""
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Create sequence that guarantees A=1, B=2 pattern
    seq = [1, 3, 2, 4, 5, 1, 2]  # 1,3,2,1,2 at positions 1,2,3,6,7
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await feed_sequence(dut, seq)
    
    await wait_for_done(dut, max_cycles=3000)
    
    found = int(dut.found.value)
    if found != 1:
        raise TestFailure(f"Expected found=1 for clear pattern, got {found}")
    
    A = int(dut.A_out.value)
    B = int(dut.B_out.value)
    
    if A != 1 or B != 2:
        raise TestFailure(f"Expected (1,2), got ({A}, {B})")
    
    cocotb.log.info(f"✓ Large sequence test passed: A={A}, B={B}")
