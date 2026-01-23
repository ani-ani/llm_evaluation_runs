import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE_A = 4
ARRAY_SIZE_B = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sweet_diet(dut):
    """Test sweet_diet module with scaled-down problem."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Test cases: (m, k, a_list, b_list, expected_result, is_forever, description)
    test_cases = [
        # Example 1: Finite case (should get 1)
        (6, 5, [2,1,6,3,5,3], [1,2,5,3,5], 1, False, "Sample 1: Finite (answer=1)"),
        # Example 2: Infinite case (should get forever)
        (6, 4, [2,1,6,3,5,3], [1,2,5,3], 0, True, "Sample 2: Infinite (forever)"),
        # Additional test: Another finite case
        (4, 3, [5,3,2,1], [1,1,2], 2, False, "Finite: 2 more"),
        # Additional test: Another infinite case
        (3, 2, [1,1,1], [1,2], 0, True, "Infinite: equal fractions"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (m, k, a_list, b_list, expected_result, is_forever, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {test_idx+1}: {description}")
        cocotb.log.info(f"m={m}, k={k}")
        cocotb.log.info(f"a={a_list}")
        cocotb.log.info(f"b={b_list}")
        
        try:
            # Scale down for hardware constraints
            # m must be ≤ 4 for our hardware
            if m > 4:
                cocotb.log.warning(f"  SKIPPED: m={m} > hardware limit 4")
                continue
            
            # k must be ≤ 8 for our hardware
            if k > 8:
                cocotb.log.warning(f"  SKIPPED: k={k} > hardware limit 8")
                continue
            
            # Set inputs
            dut.m.value = m
            dut.k.value = k
            
            # Set a_i values (pad with zeros if needed)
            for i in range(ARRAY_SIZE_A):
                if i < len(a_list):
                    val = clamp_to_width(a_list[i], DATA_WIDTH)
                else:
                    val = 0
                
                # Use getattr for individual ports
                port_name = f'a_{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = val
                else:
                    raise TestFailure(f"Signal {port_name} not found")
            
            # Set b_i values (pad with zeros if needed)
            for i in range(ARRAY_SIZE_B):
                if i < len(b_list):
                    val = clamp_to_width(b_list[i], 4)  # b_i is 4-bit
                else:
                    val = 0
                
                port_name = f'b_{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = val
                else:
                    raise TestFailure(f"Signal {port_name} not found")
            
            # Start computation
            if is_sequential:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Read is_forever if exists, otherwise check result == 255
            if has_signal(dut, 'is_forever'):
                is_forever_actual = int(dut.is_forever.value) == 1
            else:
                is_forever_actual = (result == 255)
            
            # Verify
            if is_forever:
                if not is_forever_actual:
                    raise TestFailure(f"Expected 'forever', got result={result}")
                else:
                    cocotb.log.info(f"  PASS: Correctly detected infinite (result={result})")
            else:
                if is_forever_actual:
                    raise TestFailure(f"Expected finite result {expected_result}, got 'forever'")
                elif result != expected_result:
                    raise TestFailure(f"Expected {expected_result}, got {result}")
                else:
                    cocotb.log.info(f"  PASS: result={result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        if is_sequential:
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
