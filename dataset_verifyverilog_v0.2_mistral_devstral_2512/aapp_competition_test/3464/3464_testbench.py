import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
def test_casino_profit_calculator(dut):
    """Test the casino profit calculator with various inputs"""
    
    # Helper function to convert float to Q8.8 format
    def to_q8_8(val):
        return int(val * 256) & 0xFFFF
    
    # Helper function to convert Q16.16 to float
    def from_q16_16(val):
        # Handle sign extension if needed
        if val >= 2**31:
            val = val - 2**32
        return val / 65536.0
    
    # Test cases: (x, p, expected_profit)
    test_cases = [
        (0.0, 49.9, 0.0),      # No refund, p<50 -> 0
        (50.0, 49.85, 7.10178453),  # With refund
        (0.0, 0.0, 0.0),       # Zero probability
        (0.0, 40.0, 0.0),      # Low probability, no refund
        (30.0, 45.0, 0.0),     # Moderate refund, still losing
        (80.0, 49.0, 0.0),     # High refund, low p
        (20.0, 49.9, 0.0),     # Sample from problem description
        (100.0, 0.0, 0.0),     # Edge case: x=100 (though x<100)
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (x_val, p_val, expected) in enumerate(test_cases):
        # Convert inputs to Q8.8
        x_q8 = to_q8_8(x_val)
        p_q8 = to_q8_8(p_val)
        
        # Set inputs
        dut.x_in.value = x_q8
        dut.p_in.value = p_q8
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        profit_raw = dut.profit.value
        
        # Convert to integer and handle as signed 32-bit
        profit_int = int(profit_raw)
        if profit_int >= 2**31:
            profit_int -= 2**32
        
        profit_float = profit_int / 65536.0
        
        # Check if within tolerance
        error = abs(profit_float - expected)
        tolerance = 0.01  # 1% error tolerance for scaled expectations
        
        if error < tolerance or (expected == 0.0 and profit_float < 0.01):
            dut._log.info(f"Test {i+1} PASS: x={x_val}, p={p_val} -> {profit_float:.6f} (expected {expected:.6f})")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAIL: x={x_val}, p={p_val} -> {profit_float:.6f} (expected {expected:.6f}, error={error:.6f})")
    
    dut._log.info(f"
Result: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
def test_edge_cases(dut):
    """Test edge cases around boundaries"""
    def to_q8_8(val):
        return int(val * 256) & 0xFFFF
    
    def from_q16_16(val):
        if val >= 2**31:
            val = val - 2**32
        return val / 65536.0
    
    # Edge case: x very small
    dut.x_in.value = to_q8_8(0.1)
    dut.p_in.value = to_q8_8(49.99)
    await Timer(10, units='ns')
    profit = from_q16_16(int(dut.profit.value))
    dut._log.info(f"Edge case x=0.1, p=49.99: profit={profit:.6f}")
    
    # Edge case: p very close to 50
    dut.x_in.value = to_q8_8(50.0)
    dut.p_in.value = to_q8_8(49.99)
    await Timer(10, units='ns')
    profit = from_q16_16(int(dut.profit.value))
    dut._log.info(f"Edge case x=50, p=49.99: profit={profit:.6f}")
    
    dut._log.info("Edge cases completed")
