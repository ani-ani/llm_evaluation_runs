import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def calc_min_rest(days):
    """Reference Python implementation for DP"""
    if not days:
        return 0
    
    # dp[i][state]: max active days ending at state on day i
    # state: 0=rest, 1=contest, 2=sport
    dp = [[0]*3 for _ in range(len(days))]
    
    # Day 0 initialization
    if days[0] == 1:  # contest
        dp[0][1] = 1
    elif days[0] == 2:  # sport
        dp[0][2] = 1
    elif days[0] == 3:  # both
        dp[0][1] = 1
        dp[0][2] = 1
    # days[0] == 0: all 0
    
    for i in range(1, len(days)):
        a = days[i]
        # Rest: can always rest
        dp[i][0] = max(dp[i-1])
        
        # Contest: only if available (a==1 or a==3) and prev != contest
        if a in (1, 3):
            dp[i][1] = max(dp[i-1][0], dp[i-1][2]) + 1
        
        # Sport: only if available (a==2 or a==3) and prev != sport
        if a in (2, 3):
            dp[i][2] = max(dp[i-1][0], dp[i-1][1]) + 1
    
    max_active = max(dp[-1])
    return len(days) - max_active

@cocotb.test()
async def test_vacation_scheduler(dut):
    """Test the vacation scheduler module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.day_data.value = 0
    dut.day_index.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (days_list, expected_output)
    test_cases = [
        ([1, 3, 2, 0], 2),
        ([1, 3, 3, 2, 1, 2, 3], 0),
        ([2, 2], 1),
        ([0], 1),
        ([3, 3, 3], 0),
        ([0, 0, 1, 1, 0, 0, 0, 0, 1, 0], 8),
        ([1, 1], 1),
        ([2, 3], 0),
        ([3, 0], 1),
        ([0, 3], 1),
        ([1, 3, 1, 3, 1, 3, 1, 3], 0),
        ([2, 2, 2, 2, 2, 2], 5)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for days, expected in test_cases:
        dut._log.info(f"Testing case: {days} -> Expected: {expected}")
        
        # Reset state
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Load data into internal buffer
        # Send each day's data with index
        for i, day_val in enumerate(days):
            dut.day_data.value = day_val
            dut.day_index.value = i
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
        
        dut.data_valid.value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 2000  # Safety timeout
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Timeout waiting for done signal. Case: {days}")
        
        # Read result
        result = int(dut.min_rest_days.value)
        
        if result != expected:
            raise TestFailure(
                f"Mismatch for {days}: got {result}, expected {expected}"
            )
        
        passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
