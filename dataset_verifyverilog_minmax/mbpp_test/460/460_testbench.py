import cocotb
from cocotb.triggers import Timer
from cocotb.types import Range

@cocotb.test()
async def test_extract(dut):
    def pack_sublists(sublists):
        # Convert to 4 sublists of 4 elements (zero-padded)
        padded = [sub + [0]*(4-len(sub)) for sub in sublists]
        padded += [[0]*4] * (4 - len(sublists))  # Pad to 4 sublists
        # Flatten and pack to 128-bit integer
        flat = [elem for sub in padded for elem in sub]
        val = 0
        for elem in flat:
            val = (val << 8) | elem
        return val
    
    # Original tests adapted with padding
    # Format: (input_sublists, expected_result)
    test_cases = [
        ([[1, 2], [3, 4, 5], [6, 7, 8, 9]], [1, 3, 6]),
        ([[1,2,3],[4, 5]], [1, 4]),
        ([[9,8,1],[1,2]], [9, 1])
    ]
    
    passed = 0
    for idx, (input_sublists, expected) in enumerate(test_cases):
        # Pad expected output to 4 elements
        expected_padded = expected + [0] * (4 - len(expected))
        expected_val = 0
        for elem in expected_padded:
            expected_val = (expected_val << 8) | elem
        
        # Set input and wait
        dut.flat_array.value = pack_sublists(input_sublists)
        await Timer(1, units='ns')
        
        # Verify only relevant elements
        actual = dut.result.value.integer
        valid_bytes = len(expected)
        mask = (1 << (32 - valid_bytes * 8)) - 1
        if (actual >> (valid_bytes * 8)) == 0 and ((actual >> (32 - valid_bytes * 8)) & ~mask) == (expected_val >> (32 - valid_bytes * 8)):
            passed += 1
            dut._log.info(f"PASS #{idx+1}: {input_sublists} -> {expected}")
        else:
            actual_vals = [(actual >> i) & 0xFF for i in range(24, -8, -8)]
            dut._log.error(f"FAIL #{idx+1}: Input={input_sublists}
	Expected (checked {valid_bytes} bytes): {expected}
	Got: {actual_vals}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")