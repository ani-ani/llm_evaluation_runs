import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_odometer_verifier(dut):
    """Test odometer verifier with multiple scenarios"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.entry_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (entries, expected_result)
    # Expected: 0=seems legit, 1=insufficient service, 2=tampered
    test_cases = [
        # Sample 1: seems legit
        [
            (2017, 4, 0),
            (2017, 8, 12000),
            (2018, 8, 42000)
        ],
        # Sample 2: insufficient service (42001 > 30000 over 12 months)
        [
            (2017, 4, 0),
            (2017, 8, 12000),
            (2018, 8, 42001)
        ],
        # Sample 3: tampered (1000 km in 2 months < 4000 minimum)
        [
            (2017, 11, 0),
            (2018, 1, 1000)
        ],
        # Sample 4: seems legit (0 km in 1 month is ok)
        [
            (2013, 1, 0),
            (2013, 2, 0)
        ],
        # Sample 5: insufficient service (1000 km over 5 months < 30000 but > 12 months? No, 5 < 12)
        # Actually: 5 months, 1000 km - both within limits, seems legit? Wait...
        # 1000 km / 5 months = 200 km/month < 2000 minimum -> TAMPERED
        [
            (1980, 1, 0),
            (1980, 6, 1000)
        ],
        # Additional test: rollover case
        [
            (2020, 1, 99000),
            (2020, 2, 1000)  # Wrapped: 99000->0->1000 = 2000 km (valid)
        ]
    ]
    
    expected_results = [0, 1, 2, 0, 2, 0]
    
    for test_idx, (entries, expected) in enumerate(zip(test_cases, expected_results)):
        print(f"
Test case {test_idx + 1}: {entries}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed entries
        for i, (year, month, odometer) in enumerate(entries):
            # Wait for READ_ENTRY state or similar
            await RisingEdge(dut.clk)
            
            dut.entry_year.value = year - 1950  # Offset
            dut.entry_month.value = month
            dut.entry_odometer.value = odometer
            dut.entry_valid.value = 1
            
            await RisingEdge(dut.clk)
            dut.entry_valid.value = 0
            
            # Small delay for processing
            await Timer(5, units='ns')
        
        # Wait for completion
        timeout = 20
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Test {test_idx + 1}: Did not complete within {timeout} cycles")
        
        # Check result
        result = int(dut.result.value)
        print(f"  Expected: {expected}, Got: {result}")
        
        if result != expected:
            raise TestFailure(f"Test {test_idx + 1}: Expected {expected}, got {result}")
    
    print(f"
All {len(test_cases)} tests passed!")