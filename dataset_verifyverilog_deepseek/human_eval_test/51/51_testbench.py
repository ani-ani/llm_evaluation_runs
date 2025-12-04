import cocotb
from cocotb.triggers import Timer

def str_to_bytes(s, length=16):
    # Convert string to 16-byte array with null padding
    bytes = [ord(c) for c in s]
    return bytes + [0]*(length - len(bytes))

def process_output(bytes):
    # Remove trailing nulls for comparison
    return bytes.rstrip('\x00')

@cocotb.test()
async def test_remove_vowels(dut):
    test_cases = [
        ('', ''),
        ('abcdef
ghijklm', 'bcdf
ghjklm'),
        ('fedcba', 'fdcb'),
        ('eeeee', ''),
        ('acBAA', 'cB'),
        ('ybcd', 'ybcd')
    ]
    passed = 0
    
    for input_str, expected_str in test_cases:
        # Convert strings to byte arrays
        input_bytes = str_to_bytes(input_str)
        expected_bytes = str_to_bytes(expected_str)
        
        # Set input value
        dut.text_in.value = sum(byte << (8*i) for i, byte in enumerate(input_bytes))
        
        # Wait for combinational logic
        await Timer(1, units='ns')
        
        # Extract output bytes
        output_val = dut.text_out.value.integer
        output_bytes = bytes([(output_val >> (8*i)) & 0xFF for i in range(16)])
        
        # Process output
        processed = output_bytes.rstrip(b'\x00')
        expected = expected_str.encode('utf-8')
        
        # Compare results
        if processed == expected:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' -> '{expected_str}'")
        else:
            dut._log.error(f"FAIL: '{input_str}' -> got '{processed.decode(errors='replace')}', expected '{expected_str}'")
    
    # Summary
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")