import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
NUM_DICTS_MAX = 4
CLK_NS = 10
MAX_CYCLES = 100

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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_list_data(dicts, num_dicts):
    """Pack list of dictionary values into 64-bit data"""
    packed = 0
    for i in range(min(num_dicts, NUM_DICTS_MAX)):
        val = clamp_to_width(dicts[i], DATA_WIDTH)
        packed |= val << (i * DATA_WIDTH)
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_empty_dit(dut):
    cocotb.log.info("Testing empty dictionary check module")
    
    # Check required signals exist
    required_signals = ['clk', 'rst_n', 'start', 'list_data', 'num_dicts', 'result', 'done']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        # (dicts_list, num_dicts, expected_result, description)
        ([0, 0, 0, 0], 4, 1, "All 4 dicts empty"),
        ([1, 0, 0, 0], 3, 0, "First dict non-empty"),
        ([0, 0, 0, 0], 1, 1, "Single empty dict"),
        ([0, 0, 0, 1], 4, 0, "Last dict non-empty"),
        ([0, 0, 0, 0], 0, 1, "Zero dicts (empty list)"),
        ([65535, 65535, 65535, 65535], 4, 0, "All dicts max value"),
        ([0, 1, 0, 0], 4, 0, "Middle dict non-empty"),
        ([0, 0, 0, 0], 2, 1, "Two dicts empty"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (dicts, num_dicts, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Pack data
            packed_data = pack_list_data(dicts, num_dicts)
            dut.list_data.value = packed_data
            dut.num_dicts.value = num_dicts
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Test timeout case
    cocotb.log.info("Testing timeout detection...")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    try:
        await wait_for_done(dut, max_cycles=5)  # Force timeout
        cocotb.log.error("  FAIL: Should have timed out")
        failed += 1
    except TestFailure as e:
        if "Timeout" in str(e):
            cocotb.log.info("  PASS: Correct timeout behavior")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: Unexpected error: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed ({passed} total)")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reset_behavior(dut):
    """Test that reset clears all outputs"""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Apply reset
    await reset_dut(dut, cycles=3)
    
    # Check outputs after reset
    if is_value_defined(dut.result.value) and int(dut.result.value) != 0:
        raise TestFailure(f"Result should be 0 after reset, got {int(dut.result.value)}")
    
    if is_value_defined(dut.done.value) and int(dut.done.value) != 0:
        raise TestFailure(f"Done should be 0 after reset, got {int(dut.done.value)}")
    
    cocotb.log.info("Reset behavior test passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_idle_state(dut):
    """Test module behavior when idle (no start)"""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Set input values but don't start
    dut.list_data.value = 0xFFFF_FFFF_FFFF_FFFF
    dut.num_dicts.value = 4
    
    # Wait a few cycles
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    # Outputs should remain unchanged (0) when not started
    if is_value_defined(dut.result.value) and int(dut.result.value) != 0:
        raise TestFailure("Result should remain 0 when not started")
    
    if is_value_defined(dut.done.value) and int(dut.done.value) != 0:
        raise TestFailure("Done should remain 0 when not started")
    
    cocotb.log.info("Idle state test passed")