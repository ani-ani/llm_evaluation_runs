import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Main testbench

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_next_palindrome(dut):
    # Setup clock and reset
    CLK_NS = 10
    MAX_CYCLES = 200
    
    # Check for required signals
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module missing 'clk' signal")
    
    if not has_signal(dut, 'rst_n'):
        raise TestFailure("Module missing 'rst_n' signal")
    
    if not has_signal(dut, 'start'):
        raise TestFailure("Module missing 'start' signal")
    
    if not has_signal(dut, 'num_in'):
        raise TestFailure("Module missing 'num_in' signal")
    
    if not has_signal(dut, 'result'):
        raise TestFailure("Module missing 'result' signal")
    
    if not has_signal(dut, 'done'):
        raise TestFailure("Module missing 'done' signal")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_in.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Verify reset state
    if has_signal(dut, 'done'):
        if is_value_defined(dut.done.value):
            if int(dut.done.value) != 0:
                raise TestFailure(f"Reset: done should be 0, got {int(dut.done.value)}")
    
    # Test cases: (input, expected_output, description)
    test_cases = [
        (99, 101, "99 -> 101"),
        (1221, 1331, "1221 -> 1331"),
        (120, 121, "120 -> 121"),
        (999, 1001, "999 -> 1001"),
        (1234, 1331, "1234 -> 1331"),
        (99999999, 100000001, "99999999 -> 100000001")
    ]
    
    passed = 0
    failed = 0
    
    for i, (num, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Check if input is too large (if valid signal exists)
            if has_signal(dut, 'valid'):
                if num > 99999999:
                    dut.num_in.value = 0
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    await Timer(100, units='ns')
                    if is_value_defined(dut.valid.value):
                        if int(dut.valid.value) == 0:
                            cocotb.log.info(f"  Input {num} > 99999999, correctly flagged invalid")
                            passed += 1
                            continue
            
            # Set input
            dut.num_in.value = clamp_to_width(num, 32)
            
            # Start operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done or timeout
            done = False
            for cycle in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value):
                    if int(dut.done.value) == 1:
                        done = True
                        break
            
            if not done:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles, done never set")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Special handling for 100000001 (cannot represent in 32 bits)
            # Note: This test case may need adjustment based on Verilog implementation
            if num == 99999999 and expected > 0xFFFFFFFF:
                # In 32-bit representation, this would overflow
                # We'll check for the wrapped value or mark as expected
                cocotb.log.warning(f"  Input {num}: Expected {expected} exceeds 32-bit range")
                if result == 100000001 - (1 << 32):
                    cocotb.log.info(f"  Got wrapped value {result} (expected {expected} as 32-bit wrap)")
                    passed += 1
                    continue
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
        # Small delay between tests
        await Timer(100, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")
