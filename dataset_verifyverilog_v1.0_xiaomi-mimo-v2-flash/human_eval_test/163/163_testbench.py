import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
MAX_OUTPUT = 5
CLK_NS = 10
TIMEOUT_CYCLES = 50

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

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

async def wait_for_done(dut, max_cycles=TIMEOUT_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_generate_integers(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (a, b, expected_list)
    test_cases = [
        (2, 10, [2, 4, 6, 8]),
        (10, 2, [2, 4, 6, 8]),
        (132, 2, [2, 4, 6, 8]),  # Range 2-132 includes digits 2,4,6,8
        (17, 89, []),             # No single digits in 17-89
        (0, 0, [0]),              # Edge case: 0 is even
        (0, 1, [0]),              # Edge case
        (8, 9, [8]),              # Single digit
        (9, 7, []),               # No evens in 7-9
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a}, b={b}, expecting {expected}")
        
        try:
            # Set inputs
            dut.a.value = clamp_to_width(a, DATA_WIDTH)
            dut.b.value = clamp_to_width(b, DATA_WIDTH)
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.count.value):
                raise TestFailure("Count is undefined")
            
            count = int(dut.count.value)
            
            # Read digits array
            actual_digits = []
            for idx in range(MAX_OUTPUT):
                sig_name = f'digits_out[{idx}]' if '[' in str(dut) else f'digits_out_{idx}'
                # In some cocotb versions, accessing array elements needs specific syntax
                # Try direct access to the array handle
                try:
                    # Assuming dut.digits_out is an array of signals
                    if hasattr(dut.digits_out, '__getitem__'):
                        val = int(dut.digits_out[idx].value)
                    else:
                        # Fallback for flattened naming
                        val = int(getattr(dut, f'digits_out_{idx}').value)
                except Exception:
                    # Try manual attribute access
                    val = 0
                    if has_signal(dut, f'digits_out_{idx}'):
                        val = int(getattr(dut, f'digits_out_{idx}').value)
                actual_digits.append(val)
            
            # Extract valid digits
            found_digits = actual_digits[:count]
            
            # Check count
            if count != len(expected):
                raise TestFailure(f"Count mismatch: expected {len(expected)}, got {count}")
            
            # Check digits (order must be ascending)
            for idx, (exp_d, act_d) in enumerate(zip(expected, found_digits)):
                if exp_d != act_d:
                    raise TestFailure(f"Digit {idx} mismatch: expected {exp_d}, got {act_d}")
            
            # Check padding (remaining slots should be 0)
            for idx in range(count, MAX_OUTPUT):
                if actual_digits[idx] != 0:
                    raise TestFailure(f"Padding digit at index {idx} is {actual_digits[idx]}, expected 0")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Case {i+1}): {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
