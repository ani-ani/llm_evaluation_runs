import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def str_to_bytes(s):
    """Convert string to 128-bit integer (16 bytes, left-aligned)."""
    b = s.encode('ascii')
    val = 0
    for byte in b:
        val = (val << 8) | byte
    # Shift to fill 16 bytes (128 bits)
    val <<= 8 * (16 - len(b))
    return val

def get_prefix_int(s, length):
    """Get integer representation of prefix of length 'length'."""
    return str_to_bytes(s[:length])

@cocotb.test()
async def test_thore_checker(dut):
    """Test Thore checker logic."""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.scoreboard_size.value = 0
    dut.current_name.value = 0
    for i in range(8):
        dut.names_above[i].value = 0
        dut.names_below[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper task to run a test case
    async def run_test_case(scoreboard_size, current_name_str, names_above_strs, expected_awesome, expected_sucks, expected_prefix_len, test_name):
        dut._log.info(f"Running test: {test_name}")
        
        # Setup inputs
        dut.scoreboard_size.value = scoreboard_size
        dut.current_name.value = str_to_bytes(current_name_str)
        
        for i in range(8):
            if i < len(names_above_strs):
                dut.names_above[i].value = str_to_bytes(names_above_strs[i])
            else:
                dut.names_above[i].value = 0
            # names_below unused in core logic, but set to 0
            dut.names_below[i].value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 50:
            raise TestFailure(f"{test_name}: Timeout waiting for done")
        
        # Check results
        if expected_awesome:
            if not dut.is_awesome.value:
                raise TestFailure(f"{test_name}: Expected is_awesome=1, got {dut.is_awesome.value}")
        else:
            if dut.is_awesome.value:
                raise TestFailure(f"{test_name}: Expected is_awesome=0, got {dut.is_awesome.value}")
                
        if expected_sucks:
            if not dut.sucks.value:
                raise TestFailure(f"{test_name}: Expected sucks=1, got {dut.sucks.value}")
        else:
            if dut.sucks.value:
                raise TestFailure(f"{test_name}: Expected sucks=0, got {dut.sucks.value}")
        
        if not expected_awesome and not expected_sucks:
            # Check prefix length
            actual_len = int(dut.result_prefix.value)
            if actual_len != expected_prefix_len:
                raise TestFailure(f"{test_name}: Expected prefix length {expected_prefix_len}, got {actual_len}")
            
            # Check prefix string content if needed (optional)
            # dut._log.info(f"Result string int: {int(dut.result_string.value)}")

    # Test 1: Sample 1 - Another Thore above, but not ThoreHusfeld
    # ThoreTiemann vs ThoreHusfeldt
    # Thore (5 chars) matches. T(6) differs. H(6) matches 'ThoreH' matches.
    # ThoreTiemann length 11. ThoreHusfeldt length 13.
    # Prefixes:
    # 1: T vs T
    # 2: Th vs Th
    # 3: Tho vs Tho
    # 4: Thor vs Thor
    # 5: Thore vs Thore
    # 6: ThoreT vs ThoreH -> DIFFERENT. So prefix length 6.
    await run_test_case(1, "ThoreHusfeldt", ["ThoreTiemann"], False, False, 6, "Sample 1 (ThoreH)")
    
    # Test 2: Sample 2 - First
    # Scoreboard size 0 means first (or names_above empty)
    await run_test_case(0, "ThoreHusfeldt", [], True, False, 0, "Sample 2 (Awesome)")
    
    # Test 3: Sample 3 - Thore sucks
    # ThoreHusfeldter is above.
    # ThoreHusfeld (12 chars) matches.
    # ThoreHusfeldt (13 chars) is prefix of ThoreHusfeldter, so ThoreHusfeldt < ThoreHusfeldter.
    # The condition for "sucks": anyone above has prefix "ThoreHusfeld" (12 chars).
    await run_test_case(1, "ThoreHusfeldt", ["ThoreHusfeldter"], False, True, 0, "Sample 3 (Sucks)")
    
    # Test 4: New case - Johan above
    # JohanSannemo vs ThoreHusfeldt
    # J vs T. 1st char diff.
    await run_test_case(1, "ThoreHusfeldt", ["JohanSannemo"], False, False, 1, "Johan case")

    # Test 5: Edge case - ThoreThore above
    # ThoreThore vs ThoreHusfeldt
    # Thore matches (5).
    # ThoreT vs ThoreH -> diff at 6.
    await run_test_case(1, "ThoreHusfeldt", ["ThoreThore"], False, False, 6, "ThoreThore case")

    dut._log.info("All tests passed!")
