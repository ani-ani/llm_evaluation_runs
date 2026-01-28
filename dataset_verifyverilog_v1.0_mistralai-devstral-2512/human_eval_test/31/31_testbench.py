import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_is_prime(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    CLK_NS = 10
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (input, expected_prime, description)
    test_cases = [
        (6, False, "6 is composite"),
        (101, True, "101 is prime"),
        (11, True, "11 is prime"),
        (13441, True, "13441 is prime"),
        (61, True, "61 is prime"),
        (4, False, "4 is composite"),
        (1, False, "1 is not prime"),
        (5, True, "5 is prime"),
        (11, True, "11 is prime (duplicate)"),
        (17, True, "17 is prime"),
        (5 * 17, False, "85 is composite"),
        (11 * 7, False, "77 is composite"),
        (13441 * 19, False, "255379 is composite"),
        (0, False, "0 is not prime"),
        (2, True, "2 is prime"),
        (3, True, "3 is prime"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (num={num})")
        try:
            # Clamp to 16 bits for safety
            num_clamped = clamp_to_width(num, 16)
            
            # Assign input
            if has_signal(dut, 'num_in'):
                dut.num_in.value = num_clamped
            else:
                # Check for alternative names
                if has_signal(dut, 'num'):
                    dut.num.value = num_clamped
                elif has_signal(dut, 'input_num'):
                    dut.input_num.value = num_clamped
                else:
                    raise TestFailure("No input signal found")
            
            # Trigger calculation if sequential
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done signal
                max_cycles = 1000
                for cycle in range(max_cycles):
                    await RisingEdge(dut.clk)
                    if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                    # Also check timeout without done signal
                    if cycle >= 256 and not has_signal(dut, 'done'):
                        await Timer(100, units='ns')  # Combinational fallback
                        break
                else:
                    raise TestFailure(f"Timeout after {max_cycles} cycles")
            else:
                # Combinational: wait for computation
                await Timer(500, units='ns')
            
            # Read result
            result_signal = None
            for name in ['result', 'is_prime', 'prime']:
                if has_signal(dut, name):
                    result_signal = getattr(dut, name)
                    break
            
            if result_signal is None:
                raise TestFailure("No result signal found")
            
            if not is_value_defined(result_signal.value):
                raise TestFailure("Result signal is undefined")
            
            result_val = int(result_signal.value)
            expected_val = 1 if expected else 0
            
            if result_val != expected_val:
                raise TestFailure(f"Expected {expected_val}, got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL test {i+1}: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
