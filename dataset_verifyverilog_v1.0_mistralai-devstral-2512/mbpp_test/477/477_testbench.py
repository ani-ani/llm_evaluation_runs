import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Convert string to array of 8-bit integers (ASCII)
def str_to_ascii(s, max_len=8):
    arr = [0] * max_len
    for i, c in enumerate(s[:max_len]):
        arr[i] = ord(c)
    return arr

# Convert ASCII array back to string
def ascii_to_str(arr):
    return ''.join(chr(v) for v in arr)

async def write_string(dut, values):
    for i, v in enumerate(values):
        dut.string_in[i].value = clamp_to_width(v, 8)

async def read_string(dut):
    values = []
    for i in range(8):
        v = int(dut.string_out[i].value)
        values.append(v)
    return values

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_is_lower(dut):
    # Initialize inputs
    dut.string_in.value = [0] * 8
    await Timer(10, units='ns')
    
    test_cases = [
        "InValid",
        "TruE",
        "SenTenCE",
        "HELLO123",   # Mixed with numbers
        "12345678",   # No letters
        "!@#$%^&*",   # Symbols
        ""            # Empty (all zeros)
    ]
    
    passed = 0
    failed = 0
    
    for test_str in test_cases:
        cocotb.log.info(f"Testing: '{test_str}'")
        
        # Prepare input
        input_ascii = str_to_ascii(test_str, 8)
        await write_string(dut, input_ascii)
        await Timer(10, units='ns')
        
        # Read output
        output_ascii = await read_string(dut)
        
        # Check result
        result_str = ascii_to_str(output_ascii)
        expected_str = test_str.lower()
        
        # Pad expected to 8 chars for comparison
        expected_padded = expected_str.ljust(8, '\x00')
        
        if result_str != expected_padded:
            cocotb.log.error(f"FAIL: Input '{test_str}' -> Expected '{expected_str}', Got '{result_str.strip()}'")
            failed += 1
        else:
            passed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")