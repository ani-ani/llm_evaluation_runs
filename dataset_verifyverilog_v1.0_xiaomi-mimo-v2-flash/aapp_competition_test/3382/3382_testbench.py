import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

async def wait_for_done(dut, max_cycles=100000):
    """Wait for done signal with extended timeout for many cycles"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_challenge24(dut):
    """Test Challenge 24 module"""
    
    # Check for sequential signals
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input, expected_grade, description)
    # grade=255 means impossible
    test_cases = [
        ([3, 5, 5, 2], 1, "3 5 5 2 - grade 1 expression"),
        ([1, 1, 1, 1], 255, "1 1 1 1 - impossible"),
        ([3, 6, 2, 3], 0, "3 6 2 3 - perfect grade 0"),
        ([2, 2, 2, 3], 0, "2 2 2 3 - perfect grade 0"),
        ([1, 2, 3, 4], 0, "1 2 3 4 - perfect grade 0"),
        ([5, 5, 5, 1], 255, "5 5 5 1 - likely impossible"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (inputs, expected_grade, desc) in enumerate(test_cases, 1):
        cocotb.log.info(f"Test {test_idx}: {desc}")
        cocotb.log.info(f"  Input: {inputs}")
        
        try:
            if is_seq:
                # Set inputs
                dut.in0.value = clamp_to_width(inputs[0], 8)
                dut.in1.value = clamp_to_width(inputs[1], 8)
                dut.in2.value = clamp_to_width(inputs[2], 8)
                dut.in3.value = clamp_to_width(inputs[3], 8)
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=200000)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                
                # Check if result matches expected
                if result != expected_grade:
                    raise TestFailure(f"Expected grade {expected_grade}, got {result}")
                
                cocotb.log.info(f"  Result: grade={result} {'(possible)' if result != 255 else '(impossible)'}")
                passed += 1
            else:
                # Combinational: wait for propagation
                dut.in0.value = clamp_to_width(inputs[0], 8)
                dut.in1.value = clamp_to_width(inputs[1], 8)
                dut.in2.value = clamp_to_width(inputs[2], 8)
                dut.in3.value = clamp_to_width(inputs[3], 8)
                
                await Timer(1000, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                
                if result != expected_grade:
                    raise TestFailure(f"Expected grade {expected_grade}, got {result}")
                
                cocotb.log.info(f"  Result: grade={result}")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")