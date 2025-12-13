import cocotb
from cocotb.triggers import Timer
from fractions import Fraction

@cocotb.test()
async def test_fraction_check(dut):
    test_cases = [
        ("1/5", "5/1"),
        ("1/6", "2/1"),
        ("5/1", "3/1"),
        ("7/10", "10/2"),
        ("2/10", "50/10"),
        ("7/2", "4/2"),
        ("11/6", "6/1"),
        ("2/3", "5/2"),
        ("5/2", "3/5"),
        ("2/4", "8/4"),
        ("2/4", "4/2"),
        ("1/5", "1/5")
    ]
    
    passed = 0
    for x_str, n_str in test_cases:
        # Convert fractions to integers
        x = Fraction(x_str)
        n = Fraction(n_str)
        # Set DUT inputs
        dut.num_x.value = x.numerator
        dut.den_x.value = x.denominator
        dut.num_n.value = n.numerator
        dut.den_n.value = n.denominator
        
        await Timer(1, units='ns')
        
        # Compute expected result
        expected = (x * n).denominator == 1
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {x_str} * {n_str} => {expected}")
        else:
            dut._log.error(f"FAIL: {x_str} * {n_str} => {dut.result.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")