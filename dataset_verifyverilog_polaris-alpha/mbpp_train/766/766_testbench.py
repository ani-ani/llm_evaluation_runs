import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_pair_wise(dut):
    test_cases = [
        (8, [1,1,2,3,3,4,4,5], [(1,1),(1,2),(2,3),(3,3),(3,4),(4,4),(4,5)]),
        (5, [1,5,7,9,10], [(1,5),(5,7),(7,9),(9,10)]),
        (5, [5,1,9,7,10], [(5,1),(1,9),(9,7),(7,10)])
    ]
    
    passed = 0
    for size, elements, expected in test_cases:
        # Pad input to 8 elements
        padded = elements + [0]*(8 - len(elements))
        # Pack into 32-bit value (big-endian: first element in MSB)
        data_val = 0
        for elem in padded:
            data_val = (data_val << 4) | (elem & 0xF)
        
        dut.size.value = size
        dut.data.value = data_val
        await Timer(1, units='ns')
        
        # Validate outputs
        valid_pairs = dut.valid_count.value.integer
        errors = []
        
        for i in range(min(valid_pairs, len(expected))):
            # Extract pair from packed 56-bit output
            pair_val = (dut.pairs.value >> (8*i)) & 0xFF
            h_val = (pair_val >> 4) & 0xF
            l_val = pair_val & 0xF
            
            if (h_val, l_val) != expected[i]:
                errors.append(f"Pair {i}: Got ({h_val},{l_val}), expected {expected[i]}")
        
        # Extra output pairs should be ignored (invalid output)
        
        if len(errors) == 0 and valid_pairs == len(expected):
            passed += 1
            dut._log.info(f"PASS: size={size} data={elements}")
        else:
            error_msg = "
  ".join(errors)
            dut._log.error(f"FAIL: size={size} data={elements}")
            if valid_pairs != len(expected):
                dut._log.error(f"Invalid count mismatch: Got {valid_pairs}, expected {len(expected)}")
            if error_msg:
                dut._log.error(f"Pair mismatches:
  {error_msg}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")