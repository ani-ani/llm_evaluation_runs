import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_below_zero(dut):
    """Test the below_zero module with various operation sequences."""
    
    # Helper function to wait for done with cycle timeout
    async def wait_for_done(max_cycles=20):
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        return False
    
    # Helper function to setup operations array
    def setup_operations(ops):
        """Set up the operations array and valid_ops count."""
        # Ensure we have exactly 8 elements
        while len(ops) < 8:
            ops.append(0)
        
        # Set each element individually
        for i in range(8):
            # Convert signed value to unsigned for assignment
            val = ops[i]
            if val < 0:
                val = val + 256  # 8-bit two's complement
            dut.operations[i].value = val
        
        # Set valid_ops (binary, 1-8 range)
        dut.valid_ops.value = len([x for x in ops[:8] if x != 0 or ops.index(x) < len(ops) and ops.index(x) <= 7]) if ops else 0
        # Actually, we need to pass the original length, not counting zeros
        # Let's fix this:
        original_len = len([x for x in ops[:8] if x != 0]) if 0 in ops[:8] and ops.count(0) > 0 else len([x for x in ops[:8]] if ops else 0)
        # This is getting complex, let's just track the original length
        return len(ops) if len(ops) <= 8 else 8
    
    # Initialize
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_ops.value = 0
    for i in range(8):
        dut.operations[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("empty", [], 0),
        ("no_negative", [1, 2, 3], 3),
        ("negative_early", [1, 2, -4, 5], 4),
        ("negative_edge", [1, -1, 2, -2, 5, -5, 4, -4], 8),
        ("negative_at_end", [1, -1, 2, -2, 5, -5, 4, -5], 8),
        ("negative_start", [1, -2, 2, -2, 5, -5, 4, -4], 8),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for name, ops, expected_len in test_cases:
        dut._log.info(f"\nTest case: {name}")
        dut._log.info(f"Operations: {ops}")
        
        # Setup
        actual_ops = ops.copy()
        while len(actual_ops) < 8:
            actual_ops.append(0)
        
        for i in range(8):
            val = actual_ops[i]
            if val < 0:
                val = val + 256
            dut.operations[i].value = val
        
        valid_count = len(ops)
        dut.valid_ops.value = valid_count
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        success = await wait_for_done(max_cycles=15)
        
        if not success:
            raise TestFailure(f"Timeout waiting for done on test '{name}'")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z) on test '{name}'")
        
        result_val = int(dut.result.value)
        
        # Compute expected result
        # Check if balance ever goes negative
        balance = 0
        ever_negative = False
        for op in ops:
            balance += op
            if balance < 0:
                ever_negative = True
        expected = 1 if ever_negative else 0
        
        dut._log.info(f"Expected: {expected}, Got: {result_val}")
        
        if result_val == expected:
            dut._log.info(f"Test '{name}' passed [OK]")
            passed += 1
        else:
            raise TestFailure(f"Test '{name}' failed: expected {expected}, got {result_val}")
        
        # Wait one more cycle and verify done goes low
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            dut._log.warning(f"Done still high after completion on test '{name}'")
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
