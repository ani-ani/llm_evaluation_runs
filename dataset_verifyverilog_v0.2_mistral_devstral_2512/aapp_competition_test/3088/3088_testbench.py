import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_swap_digits_max(dut):
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number_in.value = 0
    dut.k.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to pack BCD
    def pack_bcd(s):
        # s is string like "1374"
        val = 0
        for i, c in enumerate(s):
            val |= int(c) << (4 * (len(s) - 1 - i))
        return val
    
    # Helper to unpack for display
    def unpack_bcd(val):
        return f"{(val >> 12) & 0xF}{(val >> 8) & 0xF}{(val >> 4) & 0xF}{val & 0xF}"
    
    # Test cases: (number_str, k, expected_str)
    test_cases = [
        ("1374", 2, "7413"),
        ("210", 1, "0201"), # Note: 4-digit input, so 0210 -> 0201
        ("0666", 3, "6660"), # 666 -> 0666
    ]
    
    passed = 0
    total = len(test_cases)
    
    for num_str, k_val, exp_str in test_cases:
        # Pad number to 4 digits
        num_str_padded = num_str.zfill(4)
        
        dut.number_in.value = pack_bcd(num_str_padded)
        dut.k.value = k_val
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 500:
            raise TestFailure(f"Timeout for input {num_str} k={k_val}")
        
        # Check result
        got_val = int(dut.result.value)
        got_str = unpack_bcd(got_val)
        
        # Adjust expected for 4-digit format
        exp_val = pack_bcd(exp_str.zfill(4))
        
        if got_val == exp_val:
            passed += 1
            dut._log.info(f"PASS: Input {num_str_padded} k={k_val} -> {got_str} (Expected {exp_str})")
        else:
            dut._log.error(f"FAIL: Input {num_str_padded} k={k_val} -> {got_str} (Expected {exp_str})")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} of {total} tests passed")