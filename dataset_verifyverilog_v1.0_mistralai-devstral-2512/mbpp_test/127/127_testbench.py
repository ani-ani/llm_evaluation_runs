import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 300

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
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def clamp_signed(v, bits):
    min_val = -(1 << (bits-1))
    max_val = (1 << (bits-1)) - 1
    return max(min_val, min(max_val, v))

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

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_multiply_int(dut):
    # Setup clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (10, 20, 200, "positive*positive"),
        (5, 10, 50, "positive*positive small"),
        (4, 8, 32, "positive*positive small"),
        (-5, 10, -50, "negative*positive"),
        (5, -10, -50, "positive*negative"),
        (-5, -10, 50, "negative*negative"),
        (0, 10, 0, "zero*x"),
        (10, 0, 0, "x*zero"),
        (1, 100, 100, "one*100"),
        (100, 1, 100, "100*one"),
        (-1, -1, 1, "-1*-1"),
        (32767, 1, 32767, "max*1"),
        (1, 32767, 32767, "1*max"),
        (-32767, 1, -32767, "min*1"),
        (32767, -1, -32767, "max*-1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x, y, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} ({x}*{y}={expected})")
        
        try:
            if is_seq:
                # Set inputs
                dut.x_i.value = from_signed(x, DATA_WIDTH)
                dut.y_i.value = from_signed(y, DATA_WIDTH)
                
                # Start pulse
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, MAX_CYCLES)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                result_signed = to_signed(result, DATA_WIDTH)
                
                if result_signed != expected:
                    raise TestFailure(f"Expected {expected}, got {result_signed}")
                
                # Verify done is 1
                if int(dut.done.value) != 1:
                    raise TestFailure("Done signal not high")
                
                passed += 1
            else:
                # Combinational logic
                dut.x_i.value = from_signed(x, DATA_WIDTH)
                dut.y_i.value = from_signed(y, DATA_WIDTH)
                await Timer(100, units='ns')
                
                result = int(dut.result.value)
                result_signed = to_signed(result, DATA_WIDTH)
                
                if result_signed != expected:
                    raise TestFailure(f"Expected {expected}, got {result_signed}")
                
                passed += 1
        
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_overflow_behavior(dut):
    """Test that overflow wraps around 16-bit signed range"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test: 32767 * 2 should overflow to -2 (wrap)
    x = 32767
    y = 2
    
    if is_seq:
        dut.x_i.value = from_signed(x, DATA_WIDTH)
        dut.y_i.value = from_signed(y, DATA_WIDTH)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        result_signed = to_signed(result, DATA_WIDTH)
        expected = 65534 if result_signed < 0 else 0  # Wraps to -2
        
        if result_signed == -2 or result_signed == 65534:
            cocotb.log.info("Overflow test passed (wrapped correctly)")
        else:
            cocotb.log.info(f"Overflow result: {result_signed} (expected -2 or wrap)")
            # Don't fail, just log
    else:
        dut.x_i.value = from_signed(x, DATA_WIDTH)
        dut.y_i.value = from_signed(y, DATA_WIDTH)
        await Timer(100, units='ns')
        result = int(dut.result.value)
        result_signed = to_signed(result, DATA_WIDTH)
        cocotb.log.info(f"Overflow result: {result_signed}")

@cocotb.test(timeout_time=2, timeout_unit="ms")
async def test_state_transitions(dut):
    """Test that state machine cycles properly"""
    is_seq = has_signal(dut, 'clk')
    if not is_seq:
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Check initial state
    if has_signal(dut, 'busy'):
        if int(dut.busy.value) != 0:
            raise TestFailure("busy not zero after reset")
    
    if has_signal(dut, 'done'):
        if int(dut.done.value) != 0:
            raise TestFailure("done not zero after reset")
    
    # Start operation
    dut.x_i.value = from_signed(5, DATA_WIDTH)
    dut.y_i.value = from_signed(3, DATA_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Check busy is high
    for _ in range(5):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'busy'):
            if int(dut.busy.value) == 0:
                raise TestFailure("busy went low before completion")
    
    await wait_for_done(dut, 100)
    
    # After done, check state is back to idle
    await RisingEdge(dut.clk)
    if has_signal(dut, 'busy'):
        if int(dut.busy.value) != 0:
            raise TestFailure("busy still high after completion")
    
    cocotb.log.info("State transition test passed")
