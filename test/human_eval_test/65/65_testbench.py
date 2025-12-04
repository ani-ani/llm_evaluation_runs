import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_circular_shift(dut):
    """Test adapted digital shift with variable digit counting"""
    
    def num_to_digits(num):
        """Convert number to tuple of digits (d3,d2,d1,d0)"""
        return (
            (num // 1000) % 10,
            (num // 100) % 10,
            (num // 10) % 10,
            num % 10
        )
    
    def get_num_digits(num):
        """Compute number of significant digits"""
        if num >= 1000: return 4
        if num >= 100: return 3
        if num >= 10: return 2
        return 1
    
    def format_result(digits, num_digits):
        """Convert digit array to expected string output"""
        sig_digits = list(digits[4-num_digits:]) if num_digits <4 else list(digits)
        if num_digits == 3: sig = sig_digits[-3:]
        elif num_digits ==2: sig = sig_digits[-2:]
        elif num_digits==1: sig = [sig_digits[-1]]
        else: sig = sig_digits
        return ''.join(str(d) for d in sig)
        
    test_cases = [
        (100, 2, "001"),
        (12, 2, "12"),
        (97, 8, "79"),
        (12, 1, "21"),
        (11, 101, "11")
    ]
    
    passed = 0
    for num, shift, expected in test_cases:
        dut.num.value = num
        dut.shift.value = shift
        num_digits = get_num_digits(num)
        await Timer(1, units='ns')
        
        # Extract 4 output digits
        out_digits = (
            dut.shifted_digits.value >> 12 & 0xF,
            dut.shifted_digits.value >> 8 & 0xF,
            dut.shifted_digits.value >> 4 & 0xF,
            dut.shifted_digits.value & 0xF
        )
        
        # Format actual output
        actual = format_result(out_digits, num_digits)
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {num}/{shift} => {actual}")
        else:
            dut._log.error(f"FAIL: {num}/{shift} => {actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")