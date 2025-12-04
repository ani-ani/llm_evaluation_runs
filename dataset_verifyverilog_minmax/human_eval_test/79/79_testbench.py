import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_decimal_to_binary(dut):
    test_cases = [
        (0,   "db0db"),
        (32,  "db100000db"),
        (103, "db1100111db"),
        (15,  "db1111db")
    ]
    passed = 0
    
    for decimal_val, expected in test_cases:
        dut.decimal.value = decimal_val
        await Timer(1, units='ns')
        
        # Convert output to binary string (without 0b prefix)
        output_val = dut.binary.value.integer
        bin_str = bin(output_val)[2:]  # Remove '0b' prefix
        
        # Handle zero value explicitly
        if output_val == 0:
            bin_str = "0"
        
        # Wrap with 'db' for comparison
        formatted = f"db{bin_str}db"
        
        if formatted == expected:
            passed += 1
            dut._log.info(f"PASS: {decimal_val} => {formatted}")
        else:
            dut._log.error(f"FAIL: {decimal_val}, got {formatted}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")