import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tuple_to_int(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (nums_tuple, expected_result, description)
    test_cases = [
        ((1,2,3), 123, "Three digits: 123"),
        ((4,5,6), 456, "Three digits: 456"),
        ((5,6,7), 567, "Three digits: 567"),
        ((9), 9, "Single digit: 9"),
        ((1,0), 10, "Two digits: 10"),
        ((9,9,9,9), 9999, "Four digits: 9999")
    ]
    
    passed = 0
    failed = 0
    
    for i, (nums_tuple, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Prepare input: pad to 4 elements, convert to 4-bit
            nums_list = list(nums_tuple) + [0] * (4 - len(nums_tuple))
            
            # Assign nums array individually (critical!)
            for j in range(4):
                digit_val = nums_list[j] if j < len(nums_tuple) else 0
                dut.nums[j].value = clamp_to_width(digit_val, 4)
            
            # Set length
            dut.len.value = len(nums_tuple)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
