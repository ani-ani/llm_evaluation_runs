import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import struct

def string_to_q1616(s):
    if any(c.isalpha() for c in s):
        return (None, 1)  # Flag as string
    val = float(s)
    integer = int(val)
    fractional = val - integer
    return ((integer << 16) + int(fractional * 65536), 0)  # (value, is_string)

@cocotb.test()
async def test_converter(dut):
    # Generate 100MHz clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Test cases with ASCII packing
    test_cases = [
        (("3        ", "4        "), (3.0, 4.0)),
        (("1        ", "26.45    "), (1.0, 26.45)),
        (("7.32     ", "8        "), (7.32, 8.0)),
        (("abc      ", "12.3     "), ("abc", 12.3))  # Mixed case
    ]
    
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    passed = 0
    for (in1, in2), (out1, out2) in test_cases:
        # Pack strings to 64-bit
        dut.str1.value = int.from_bytes(in1.encode('ascii'), 'big')
        dut.str2.value = int.from_bytes(in2.encode('ascii'), 'big')
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 8 cycles
        for _ in range(8):
            await RisingEdge(dut.clk)
        
        # Check outputs
        exp1 = string_to_q1616(in1.strip())
        exp2 = string_to_q1616(in2.strip())
        
        valid = True
        if exp1[1] != dut.is_str1.value:
            dut._log.error(f"STR1 type mismatch: {in1.strip()}")
            valid = False
        if exp2[1] != dut.is_str2.value:
            dut._log.error(f"STR2 type mismatch: {in2.strip()}")
            valid = False
        
        # For non-string values
        if exp1[1] == 0 and exp1[0] != dut.val1.value.integer:
            dut._log.error(f"VAL1 mismatch: Got {dut.val1.value} vs {exp1[0]}")
            valid = False
        if exp2[1] == 0 and exp2[0] != dut.val2.value.integer:
            dut._log.error(f"VAL2 mismatch: Got {dut.val2.value} vs {exp2[0]}")
            valid = False
        
        if valid:
            passed += 1
            dut._log.info(f"Passed: {in1.strip()}, {in2.strip()}")
        else:
            dut._log.error(f"Failed: {in1.strip()}, {in2.strip()}")
            
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)