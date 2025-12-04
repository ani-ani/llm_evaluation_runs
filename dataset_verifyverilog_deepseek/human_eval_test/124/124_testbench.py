import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_date_validator(dut):
    test_cases = [
        ("03-11-2000", 1),
        ("15-01-2012", 0),  # Invalid month
        ("04-0-2040", 0),   # Invalid format
        ("06-04-2020", 1),
        ("03-32-2011", 0),  # Invalid day
        ("04-31-3000", 0),  # Invalid day for month
        ("06/04/2020", 0)   # Invalid separator
    ]
    
    passed = 0
    for date_str, expected in test_cases:
        # Pad to 10 characters with nulls if needed
        padded_str = date_str.ljust(10, '\\0')
        # Convert to ASCII byte array
        ascii_val = 0
        for i, char in enumerate(padded_str):
            ascii_val |= (ord(char) & 0xFF) << (8*i)
        
        dut.date_str.value = ascii_val
        await Timer(1, units='ns')
        
        if dut.valid.value == expected:
            passed += 1
            dut._log.info(f"PASS: {date_str} => {expected}")
        else:
            dut._log.error(f"FAIL: {date_str} => {dut.valid.value}, expected {expected}")
            
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)