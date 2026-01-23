import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_compare_one(dut):
    """Test compare_one module with mixed type inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.type_a.value = 0
    dut.type_b.value = 0
    dut.data_a.value = 0
    dut.data_b.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test helper function
    async def run_test(type_a, data_a, type_b, data_b, expected_type, expected_data, description):
        dut._log.info(f"Test: {description}")
        dut.type_a.value = type_a
        dut.data_a.value = data_a
        dut.type_b.value = type_b
        dut.data_b.value = data_b
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure("Timeout waiting for done")
        
        # Check result
        if dut.result_type.value != expected_type or dut.result_data.value != expected_data:
            raise TestFailure(
                f"Mismatch: got type={dut.result_type.value}, data={dut.result_data.value} "
                f"(hex: {hex(int(dut.result_data.value))}); "
                f"expected type={expected_type}, data={expected_data} (hex: {hex(expected_data)})"
            )
        
        await RisingEdge(dut.clk)
    
    # Test cases adapted to fixed format:
    # Type encoding: 00=int, 01=float(Q16.16), 10=string
    # Integer values: direct
    # Float values: Q16.16 format (value * 65536)
    # String values: For simplicity, we encode strings as integers where:
    #  '1' = 1, '2' = 2, '2.3' or '2,3' = 23 (representing 2.3 scaled by 10)
    #  '5.1' or '5,1' = 51 (representing 5.1 scaled by 10)
    #  '6' = 6
    #  The module will parse these and convert to Q16.16 internally
    
    # Test 1: candidate(1, 2) -> 2
    await run_test(0, 1, 0, 2, 0, 2, "int vs int: 1 vs 2")
    
    # Test 2: candidate(1, 2.5) -> 2.5
    # 2.5 in Q16.16 = 2.5 * 65536 = 163840 = 0x00028000
    await run_test(0, 1, 1, 163840, 1, 163840, "int vs float: 1 vs 2.5")
    
    # Test 3: candidate(2, 3) -> 3
    await run_test(0, 2, 0, 3, 0, 3, "int vs int: 2 vs 3")
    
    # Test 4: candidate(5, 6) -> 6
    await run_test(0, 5, 0, 6, 0, 6, "int vs int: 5 vs 6")
    
    # Test 5: candidate(1, "2,3") -> "2,3"
    # "2,3" is encoded as 23 (representing 2.3)
    await run_test(0, 1, 2, 23, 2, 23, "int vs string: 1 vs '2,3'")
    
    # Test 6: candidate("5,1", "6") -> "6"
    # "5,1" encoded as 51, "6" encoded as 6
    await run_test(2, 51, 2, 6, 2, 6, "string vs string: '5,1' vs '6'")
    
    # Test 7: candidate("1", "2") -> "2"
    await run_test(2, 1, 2, 2, 2, 2, "string vs string: '1' vs '2'")
    
    # Test 8: candidate("1", 1) -> None
    # "1" = 1, 1 = 1, equal returns type 11
    await run_test(2, 1, 0, 1, 3, 0, "string vs int equal: '1' vs 1")
    
    dut._log.info("All tests passed: 8/8")