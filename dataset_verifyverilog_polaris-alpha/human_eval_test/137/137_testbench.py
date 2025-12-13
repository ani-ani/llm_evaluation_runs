import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import binascii

@cocotb.test()
async def test_compare(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    test_cases = [
        # (a_type, a_str, b_type, b_str, expected_result, expect_none)
        (0, b"1",       0, b"2",        b"2",   False),  # int vs int
        (0, b"1",       1, b"2.5",      b"2.5", False),  # int vs float
        (2, b"5,1",     2, b"6",        b"6",   False),  # string vs string
        (2, b"1",       0, b"1",        b"",     True),   # equal values
        (2, b"-3.5",    2, b"-2",       b"-2",  False)   # negative nums
    ]
    
    passed = 0
    for a_type, a_str, b_type, b_str, exp_result, exp_none in test_cases:
        # Convert strings to ASCII hex
        a_hex = binascii.hexlify(a_str).decode()
        b_hex = binascii.hexlify(b_str).decode()
        
        # Load inputs
        dut.a_type.value = a_type
        dut.b_type.value = b_type
        dut.start.value = 1
        dut.a_str.value = int.from_bytes(a_str, 'big')
        dut.b_str.value = int.from_bytes(b_str, 'big')
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 5 cycles
        for _ in range(5):
            await RisingEdge(dut.clk)
        
        # Convert result to string
        result_bytes = dut.result_str.value.buffered().tobytes()
        result_str = result_bytes.decode().strip('\\x00')
        
        # Check assertions
        if dut.none.value == exp_none:
            if exp_none or result_str == exp_result.decode():
                passed += 1
                dut._log.info(f"PASS: {a_str} vs {b_str} → {exp_result}")
            else:
                dut._log.error(f"FAIL: {result_str} ≠ {exp_result.decode()}")
        else:
            dut._log.error(f"FAIL: none={dut.none.value} expected={exp_none}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")