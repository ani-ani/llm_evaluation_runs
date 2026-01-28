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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Integer division by 10 using bit shifts (simplified for testing)
def divide_by_10(n):
    return n // 10

def first_digit_python(n):
    while n >= 10:
        n = divide_by_10(n)
    return int(n)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_first_digit(dut):
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (123, 1, "three digits"),
        (456, 4, "three digits"),
        (12, 1, "two digits"),
        (5, 5, "single digit"),
        (9999, 9, "four digits"),
        (0, 0, "zero"),
        (1, 1, "one"),
        (10, 1, "edge case 10"),
        (99, 9, "edge case 99"),
        (100, 1, "edge case 100"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num_input, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input={num_input}, Expected={expected}")
        
        try:
            # Load input
            if has_signal(dut, 'number_in'):
                dut.number_in.value = clamp_to_width(num_input, 16)
            else:
                raise TestFailure("Signal number_in not found")
            
            # Start calculation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational - just wait for result
                await Timer(100, units='ns')
            
            # Check result
            if has_signal(dut, 'first_digit'):
                if not is_value_defined(dut.first_digit.value):
                    raise TestFailure("first_digit signal undefined")
                
                result = int(dut.first_digit.value)
                
                # Verify against Python reference
                expected_result = first_digit_python(num_input)
                
                if result != expected_result:
                    raise TestFailure(
                        f"Expected {expected_result}, got {result} "
                        f"(input={num_input})"
                    )
                
                # Also check done signal if present
                if has_signal(dut, 'done'):
                    if not is_value_defined(dut.done.value):
                        raise TestFailure("done signal undefined")
                    if int(dut.done.value) != 1:
                        raise TestFailure("done signal should be 1")
                
                passed += 1
                cocotb.log.info(f"  PASS: result={result}")
            else:
                raise TestFailure("Signal first_digit not found")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            await reset_dut(dut)  # Reset after failure
        
        # Reset between tests for sequential logic
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")