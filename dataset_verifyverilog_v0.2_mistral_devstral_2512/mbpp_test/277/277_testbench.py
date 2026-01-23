import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_dict_filter_basic(dut):
    """Test basic dictionary filtering with threshold 170"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: threshold = 170
    # {'Cierra Vega': 175, 'Alden Cantrell': 180, 'Kierra Gentry': 165, 'Pierre Cox': 190}
    # Encoded: 0:175, 1:180, 2:165, 3:190
    dut.threshold.value = 170
    dut.num_entries.value = 4
    dut.key_0.value = 0
    dut.val_0.value = 175
    dut.key_1.value = 1
    dut.val_1.value = 180
    dut.key_2.value = 2
    dut.val_2.value = 165
    dut.key_3.value = 3
    dut.val_3.value = 190
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (6 cycles max)
    for _ in range(7):
        await RisingEdge(dut.clk)
    
    # Check done signal
    if dut.done.value != 1:
        raise TestFailure(f"Done not set! Got {dut.done.value}")
    
    # Check result
    # Expected: 3 valid entries: (0,175), (1,180), (3,190)
    # Count=3, entry0={key0=0,val0=175}, entry1={key1=1,val1=180}, entry2={key2=3,val2=190}
    expected_count = 3
    actual_count = int(dut.result.value) >> 56
    
    if actual_count != expected_count:
        raise TestFailure(f"Count mismatch: expected {expected_count}, got {actual_count}")
    
    # Verify each entry
    # Extract entry 0: bits [55:52] = key, [47:40] = value
    key0 = (int(dut.result.value) >> 52) & 0xF
    val0 = (int(dut.result.value) >> 40) & 0xFF
    if key0 != 0 or val0 != 175:
        raise TestFailure(f"Entry 0 incorrect: expected (0,175), got ({key0},{val0})")
    
    # Extract entry 1: bits [39:36] = key, [31:24] = value
    key1 = (int(dut.result.value) >> 36) & 0xF
    val1 = (int(dut.result.value) >> 24) & 0xFF
    if key1 != 1 or val1 != 180:
        raise TestFailure(f"Entry 1 incorrect: expected (1,180), got ({key1},{val1})")
    
    # Extract entry 2: bits [23:20] = key, [15:8] = value
    key2 = (int(dut.result.value) >> 20) & 0xF
    val2 = (int(dut.result.value) >> 8) & 0xFF
    if key2 != 3 or val2 != 190:
        raise TestFailure(f"Entry 2 incorrect: expected (3,190), got ({key2},{val2})")
    
    print(f"Test 1 PASSED: Filtered 3 entries from 4")

@cocotb.test()
async def test_dict_filter_threshold_180(dut):
    """Test filtering with threshold 180"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: threshold = 180
    dut.threshold.value = 180
    dut.num_entries.value = 4
    dut.key_0.value = 0
    dut.val_0.value = 175
    dut.key_1.value = 1
    dut.val_1.value = 180
    dut.key_2.value = 2
    dut.val_2.value = 165
    dut.key_3.value = 3
    dut.val_3.value = 190
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(7):
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Done not set!")
    
    # Expected: 2 valid entries: (1,180), (3,190)
    expected_count = 2
    actual_count = int(dut.result.value) >> 56
    
    if actual_count != expected_count:
        raise TestFailure(f"Count mismatch: expected {expected_count}, got {actual_count}")
    
    # Entry 0 should be key=1, val=180
    key0 = (int(dut.result.value) >> 52) & 0xF
    val0 = (int(dut.result.value) >> 40) & 0xFF
    if key0 != 1 or val0 != 180:
        raise TestFailure(f"Entry 0 incorrect: expected (1,180), got ({key0},{val0})")
    
    # Entry 1 should be key=3, val=190
    key1 = (int(dut.result.value) >> 36) & 0xF
    val1 = (int(dut.result.value) >> 24) & 0xFF
    if key1 != 3 or val1 != 190:
        raise TestFailure(f"Entry 1 incorrect: expected (3,190), got ({key1},{val1})")
    
    print(f"Test 2 PASSED: Filtered 2 entries")

@cocotb.test()
async def test_dict_filter_threshold_190(dut):
    """Test filtering with threshold 190"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: threshold = 190
    dut.threshold.value = 190
    dut.num_entries.value = 4
    dut.key_0.value = 0
    dut.val_0.value = 175
    dut.key_1.value = 1
    dut.val_1.value = 180
    dut.key_2.value = 2
    dut.val_2.value = 165
    dut.key_3.value = 3
    dut.val_3.value = 190
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(7):
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Done not set!")
    
    # Expected: 1 valid entry: (3,190)
    expected_count = 1
    actual_count = int(dut.result.value) >> 56
    
    if actual_count != expected_count:
        raise TestFailure(f"Count mismatch: expected {expected_count}, got {actual_count}")
    
    # Entry 0 should be key=3, val=190
    key0 = (int(dut.result.value) >> 52) & 0xF
    val0 = (int(dut.result.value) >> 40) & 0xFF
    if key0 != 3 or val0 != 190:
        raise TestFailure(f"Entry 0 incorrect: expected (3,190), got ({key0},{val0})")
    
    print(f"Test 3 PASSED: Filtered 1 entry")

@cocotb.test()
async def test_dict_filter_edge_cases(dut):
    """Test edge cases: all pass, none pass, single entry"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 4a: All pass (threshold = 0)
    dut.threshold.value = 0
    dut.num_entries.value = 2
    dut.key_0.value = 5
    dut.val_0.value = 50
    dut.key_1.value = 7
    dut.val_1.value = 100
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(7):
        await RisingEdge(dut.clk)
    
    actual_count = int(dut.result.value) >> 56
    if actual_count != 2:
        raise TestFailure(f"All pass test failed: expected 2, got {actual_count}")
    print("Test 4a PASSED: All entries pass")
    
    # Test 4b: None pass (threshold = 255)
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.threshold.value = 255
    dut.num_entries.value = 2
    dut.key_0.value = 0
    dut.val_0.value = 100
    dut.key_1.value = 1
    dut.val_1.value = 200
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(7):
        await RisingEdge(dut.clk)
    
    actual_count = int(dut.result.value) >> 56
    if actual_count != 0:
        raise TestFailure(f"None pass test failed: expected 0, got {actual_count}")
    print("Test 4b PASSED: No entries pass")
    
    # Test 4c: Single entry passing
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.threshold.value = 50
    dut.num_entries.value = 1
    dut.key_0.value = 2
    dut.val_0.value = 75
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(7):
        await RisingEdge(dut.clk)
    
    actual_count = int(dut.result.value) >> 56
    if actual_count != 1:
        raise TestFailure(f"Single entry test failed: expected 1, got {actual_count}")
    key0 = (int(dut.result.value) >> 52) & 0xF
    val0 = (int(dut.result.value) >> 40) & 0xFF
    if key0 != 2 or val0 != 75:
        raise TestFailure(f"Single entry data incorrect: expected (2,75), got ({key0},{val0})")
    print("Test 4c PASSED: Single entry pass")

@cocotb.test()
async def test_dict_filter_direct_values(dut):
    """Test with direct known values matching original test cases"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Original values: 175, 180, 165, 190
    # Keys: 0,1,2,3
    
    dut.threshold.value = 170
    dut.num_entries.value = 4
    dut.key_0.value = 0
    dut.val_0.value = 175
    dut.key_1.value = 1
    dut.val_1.value = 180
    dut.key_2.value = 2
    dut.val_2.value = 165
    dut.key_3.value = 3
    dut.val_3.value = 190
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(7):
        await RisingEdge(dut.clk)
    
    # Verify the 3 expected entries are present (order in result may differ)
    result_val = int(dut.result.value)
    count = result_val >> 56
    
    if count != 3:
        raise TestFailure(f"Expected 3 valid entries, got {count}")
    
    # Collect all entries from result
    entries = []
    for i in range(3):
        shift = 52 - (i * 12)  # 52, 40, 28
        key = (result_val >> shift) & 0xF
        val = (result_val >> (shift - 8)) & 0xFF
        entries.append((key, val))
    
    expected_set = {(0,175), (1,180), (3,190)}
    actual_set = set(entries)
    
    if actual_set != expected_set:
        raise TestFailure(f"Entries mismatch: expected {expected_set}, got {actual_set}")
    
    print(f"Test 5 PASSED: All tests completed successfully")
    print(f"Summary: 5 test suites passed (basic, threshold_180, threshold_190, edge_cases, direct_values)")
