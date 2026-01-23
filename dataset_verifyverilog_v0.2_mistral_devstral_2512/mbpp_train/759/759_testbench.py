import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_string_decimal_validator(dut):
    """Test decimal number validation with fixed-width strings"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_array.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert string to fixed 8-char array
    def str_to_array(s):
        arr = [0] * 8
        for i, c in enumerate(s):
            if i < 8:
                arr[i] = ord(c)
        # Fill remaining with spaces (0x20)
        for i in range(len(s), 8):
            arr[i] = 0x20
        # Pack into single value for Verilog
        packed = 0
        for i in range(8):
            packed |= (arr[i] << (i * 8))
        return packed
    
    # Helper to run one test
    async def run_test(test_str, expected_valid, test_name):
        dut.char_array.value = str_to_array(test_str)
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 15 cycles to be safe)
        for _ in range(15):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        if not dut.done.value:
            raise TestFailure(f"{test_name}: done signal never asserted")
        
        actual_valid = int(dut.valid.value)
        if actual_valid != expected_valid:
            raise TestFailure(f"{test_name}: Expected valid={expected_valid}, got {actual_valid} for input '{test_str}'")
        
        print(f"{test_name}: PASS (input='{test_str}', valid={actual_valid}, expected={expected_valid})")
    
    # Test cases from specification
    await run_test('123.11', 1, 'Test 1: 123.11')
    await run_test('e666.86', 0, 'Test 2: e666.86')
    await run_test('3.124587', 0, 'Test 3: 3.124587')
    await run_test('1.11', 1, 'Test 4: 1.11')
    await run_test('1.1.11', 0, 'Test 5: 1.1.11')
    
    # Additional edge cases
    await run_test('.123', 0, 'Edge 1: .123 (starts with dot)')
    await run_test('123.', 0, 'Edge 2: 123. (ends with dot)')
    await run_test('1', 1, 'Edge 3: 1 (integer only)')
    await run_test('12345678', 1, 'Edge 4: 12345678 (max 8 digits)')
    await run_test('1.1', 1, 'Edge 5: 1.1 (one fractional)')
    await run_test('0.01', 1, 'Edge 6: 0.01 (leading zero)')
    await run_test('12.34', 1, 'Edge 7: 12.34 (two fractional)')
    await run_test('12a.34', 0, 'Edge 8: 12a.34 (invalid char)')
    await run_test(' ', 0, 'Edge 9: space (empty)')
    
    print("
=== Summary: All 12 tests passed ===")