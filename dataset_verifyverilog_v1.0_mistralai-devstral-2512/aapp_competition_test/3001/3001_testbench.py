import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=20000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_palindrome_counter(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Detect K (number of digit inputs)
    K = 0
    while has_signal(dut, f'digits_in_{K}'):
        K += 1
    if K == 0 and has_signal(dut, 'digits_in'):
        # Try array access
        try:
            _ = dut.digits_in[0]
            # Try a few indices to find limit or assume 16
            # In the prompt spec, we used 16. Let's check a higher index.
            for i in range(1, 32):
                try:
                    _ = dut.digits_in[i]
                    K = i + 1
                except:
                    break
        except:
            pass
    
    # Default to 16 if not found
    if K == 0:
        K = 16
    
    cocotb.log.info(f"Detected array size K={K}")

    # Test cases
    # Format: (input_string, expected_steps)
    test_cases = [
        ("0", 0),
        ("009990001", 3),
        ("29998", 5),
        ("610", 4),
        ("981", 2),
        ("9084194700940903797191718247801197019268", 54) # 40 digits, might be too big for K=16, will be truncated or handled
    ]

    for input_str, expected_steps in test_cases:
        # Prepare digits
        input_digits = [int(c) for c in input_str]
        
        # If input length > K, we might need to truncate or adapt. 
        # The prompt assumes K is the number of wheels. 
        # If the test input is longer than K, we usually take the least significant K digits 
        # (or the input implies K is that length). 
        # Since we detected K, let's pad with leading zeros if shorter, or truncate if longer.
        # NOTE: For the 40-digit example, if K=16, we can only test a subset or fail. 
        # We will take the last K digits of the input.
        
        if len(input_digits) > K:
            # Take the last K digits (least significant)
            digits = input_digits[-K:]
        else:
            # Pad with leading zeros to length K
            digits = [0] * (K - len(input_digits)) + input_digits
        
        cocotb.log.info(f"Test case: Input '{input_str}' -> Digits {digits} (Expected {expected_steps})")

        # Write inputs
        for i in range(K):
            # Check if individual signals exist
            if has_signal(dut, f'digits_in_{i}'):
                getattr(dut, f'digits_in_{i}').value = digits[i]
            elif has_signal(dut, 'digits_in'):
                try:
                    # Try array access
                    dut.digits_in[i].value = digits[i]
                except Exception as e:
                    cocotb.log.error(f"Failed to assign digits_in[{i}]: {e}")
                    raise
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        await wait_for_done(dut)

        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
            
        result = int(dut.result.value)
        
        # Adjust expected value if input was truncated
        if len(input_str) > K:
            cocotb.log.warning(f"Input truncated to {K} digits. Result is for truncated input.")
            # Recalculate expected for truncated input if possible, otherwise skip check or warn
            # For this test, we will just log the result as we don't have the expected value for arbitrary truncation
            cocotb.log.info(f"Result (truncated input): {result}")
        else:
            if result != expected_steps:
                raise TestFailure(f"Expected {expected_steps}, got {result}")
            else:
                cocotb.log.info(f"PASS: Result {result}")

        # Reset for next test
        await reset_dut(dut)