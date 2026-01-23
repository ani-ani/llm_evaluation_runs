import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Helper to check defined values
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Reference Python implementation
def get_odd_collatz_reference(n):
    sequence = []
    current = n
    max_iter = 50  # Safety limit for Python ref
    while current != 1 and max_iter > 0:
        if current % 2 != 0:
            sequence.append(current)
        if current % 2 == 0:
            current = current // 2
        else:
            current = 3 * current + 1
        max_iter -= 1
    if current == 1:
        sequence.append(1)
    return sorted(list(set(sequence)))

@cocotb.test(timeout_time=5000, timeout_unit="us")
async def test_odd_collatz(dut):
    """Test the odd collatz module."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (scaled to ensure max 8 odd numbers)
    test_cases = [
        (14, [1, 5, 7, 11, 13, 17]),
        (5, [1, 5]),
        (12, [1, 3, 5]),
        (1, [1]),
        (9, [1, 7, 25]),  # 9->28->14->7->22->11->34->17->52->26->13->40->20->10->5->16->8->4->2->1
    ]

    for n, expected in test_cases:
        dut._log.info(f"Testing with n={n}")
        
        # Start pulse
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Collect results
        collected = []
        cycles = 0
        max_cycles = 200 # Safe upper bound for seq + sort + output

        while cycles < max_cycles:
            await RisingEdge(dut.clk)
            cycles += 1
            
            # Check done
            if not is_value_defined(dut.done.value):
                continue
            
            # Check result validity
            if not is_value_defined(dut.result.value):
                # If done is high, we might be at the end, otherwise it's intermediate X
                if int(dut.done.value) == 1:
                    break
                continue

            res_val = int(dut.result.value)
            done_val = int(dut.done.value)

            # Collect non-zero values (assuming 0 is invalid/placeholder)
            if res_val > 0:
                collected.append(res_val)
            
            if done_val == 1:
                break
        
        # Verification
        if collected != expected:
            raise TestFailure(f"Test failed for n={n}. Expected {expected}, got {collected}")
        
        dut._log.info(f"Passed: {collected}")

    dut._log.info("All tests passed [OK]")

@cocotb.test(timeout_time=5000, timeout_unit="us")
async def test_edge_cases(dut):
    """Test edge cases."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test n=2 (should be [1])
    # Test n=1024 (power of 2, goes straight to 1)
    # Test n=3 (classic 3n+1)
    edge_cases = [
        (2, [1]),
        (1024, [1]),
        (3, [1, 3, 10]),
    ]
    
    for n, expected in edge_cases:
        dut._log.info(f"Edge test with n={n}")
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        collected = []
        cycles = 0
        while cycles < 200:
            await RisingEdge(dut.clk)
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            if is_value_defined(dut.result.value):
                val = int(dut.result.value)
                if val > 0:
                    collected.append(val)
        
        # For 3: 3->10->5->16->8->4->2->1. Odds: 3, 5, 1. Sorted: 1, 3, 5.
        # Wait, reference for 3: 3, 10, 5, 16, 8, 4, 2, 1. Odds: 3, 5, 1. Sorted: 1, 3, 5.
        # But expected provided in prompt test case for 3 was [1, 3, 10]? No, that was incorrect python logic in prompt.
        # Correct odd numbers for 3 are 1, 3, 5.
        # Let's verify with my python ref logic.
        python_ref = get_odd_collatz_reference(n)
        
        if collected != python_ref:
             raise TestFailure(f"Edge test failed for n={n}. Ref {python_ref}, got {collected}")
             
    dut._log.info("Edge tests passed [OK]")
