import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def str_to_ascii_array(date_str):
    """Convert date string to 10 ASCII byte values."""
    if len(date_str) != 10:
        return [0] * 10
    return [ord(c) for c in date_str]

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_date_validator_basic(dut):
    """Test basic date validation functionality."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(10):
        getattr(dut, f'char_{i}').value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (date_string, expected_valid)
    test_cases = [
        ('03-11-2000', True),
        ('15-01-2012', False),  # month > 12
        ('04-0-2040', False),   # day < 1 (single digit 0)
        ('06-04-2020', True),
        ('01-01-2007', True),
        ('03-32-2011', False),  # day > 31 for month 3
        ('04-31-3000', False),  # day > 30 for month 4
        ('06-06-2005', True),
        ('21-31-2000', False),  # month > 12
        ('04-12-2003', True),
        ('00-01-2000', False),  # month 00
        ('12-31-2000', True),   # max valid month and day
        ('02-29-2000', True),   # Feb 29
        ('02-30-2000', False),  # Feb 30
        ('09-31-2000', False),  # Sep 31
        ('11-31-2000', False),  # Nov 31
        ('01-31-2000', True),   # Jan 31
        ('04-31-2000', False),  # Apr 31
        ('06-31-2000', False),  # Jun 31
        ('08-31-2000', True),   # Aug 31
        ('10-31-2000', True),   # Oct 31
        ('12-31-2000', True),   # Dec 31
        ('04-30-2000', True),   # Apr 30
        ('09-30-2000', True),   # Sep 30
        ('11-30-2000', True),   # Nov 30
        ('02-01-2000', True),   # Feb 1
        ('02-28-2000', True),   # Feb 28
        ('03-00-2000', False),  # day 00
        ('13-01-2000', False),  # month 13
        ('01-32-2000', False),  # day 32
        ('00-00-2000', False),  # both invalid
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (date_str, expected_valid) in enumerate(test_cases):
        dut._log.info(f"Test {i}: Testing '{date_str}' (expected: {expected_valid})")
        
        # Convert string to ASCII array
        ascii_vals = str_to_ascii_array(date_str)
        
        # Assign each character to the dut
        for j in range(10):
            getattr(dut, f'char_{j}').value = ascii_vals[j]
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with cycle timeout
        done_received = False
        for cycle in range(20):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
                
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Test {i}: Timeout waiting for done signal")
        
        # Read and validate result
        if not is_value_defined(dut.valid.value):
            raise TestFailure(f"Test {i}: Output valid is undefined (X/Z)")
        
        result = bool(int(dut.valid.value))
        
        if result != expected_valid:
            raise TestFailure(f"Test {i}: '{date_str}' expected {expected_valid}, got {result}")
        
        passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_date_validator_invalid_format(dut):
    """Test invalid format cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(10):
        getattr(dut, f'char_{i}').value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test invalid format cases
    test_cases = [
        ('03a11-2000', False, 'invalid char at pos 2'),
        ('03-11b2000', False, 'invalid char at pos 5'),
        ('a3-11-2000', False, 'invalid digit at pos 0'),
        ('03-1c-2000', False, 'invalid digit at pos 3'),
        ('03-11-200a', False, 'invalid digit at pos 9'),
        ('03/11/2000', False, 'wrong separator'),
        ('03-11-200', False, 'too short'),
        ('03-11-20000', False, 'too long'),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for date_str, expected, desc in test_cases:
        ascii_vals = str_to_ascii_array(date_str)
        for j in range(10):
            getattr(dut, f'char_{j}').value = ascii_vals[j]
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_received = False
        for cycle in range(20):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Edge case '{desc}': timeout waiting for done")
        
        if not is_value_defined(dut.valid.value):
            raise TestFailure(f"Edge case '{desc}': valid is undefined")
        
        result = bool(int(dut.valid.value))
        if result != expected:
            raise TestFailure(f"Edge case '{desc}': expected {expected}, got {result}")
        
        passed += 1
        dut._log.info(f"Edge case '{desc}' [OK]")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nFormat tests: {passed}/{total} passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} format tests passed")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_date_validator_specific_issue_cases(dut):
    """Test cases from the original problem that were previously failing."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(10):
        getattr(dut, f'char_{i}').value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Original test cases from problem statement
    test_cases = [
        ('03-11-2000', True),
        ('15-01-2012', False),
        ('04-0-2040', False),
        ('06-04-2020', True),
        ('01-01-2007', True),
        ('03-32-2011', False),
        ('04-31-3000', False),
        ('06-06-2005', True),
        ('21-31-2000', False),
        ('04-12-2003', True),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (date_str, expected_valid) in enumerate(test_cases):
        dut._log.info(f"Problem test {i}: '{date_str}' expected {expected_valid}")
        
        ascii_vals = str_to_ascii_array(date_str)
        for j in range(10):
            getattr(dut, f'char_{j}').value = ascii_vals[j]
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for cycle in range(20):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        
        if not is_value_defined(dut.valid.value):
            raise TestFailure(f"Problem test {i}: valid undefined")
        
        result = bool(int(dut.valid.value))
        if result != expected_valid:
            raise TestFailure(f"Problem test {i}: '{date_str}' expected {expected_valid}, got {result}")
        
        passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nProblem tests: {passed}/{total} passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} problem tests passed")
