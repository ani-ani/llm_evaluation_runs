import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH CONFIGURATION
# ============================================================================

DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 17
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_subset_sum_mask(dut):
    """Test the subset sum mask module."""
    
    # Initialize signals
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    dut.coin_in.value = 0
    dut.rst_n.value = 0
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    await Timer(100, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, k, coins, expected_x_list)
    # Scaled test cases that fit within n=8, k=16
    test_cases = [
        (5, 1, [1, 500, 205, 6, 355], [0, 1]),
        (8, 15, [13, 3, 5, 5, 6, 14, 5, 5], [0, 5, 10, 15]),
        (3, 10, [5, 5, 5], [0, 5, 10]),
        (4, 6, [2, 2, 3, 5], [0, 2, 3, 5, 6]),
        (2, 8, [3, 5], [0, 3, 5, 8]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, coins, expected_x_list) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: n={n}, k={k}, coins={coins}")
        
        try:
            # Ensure coins are within 8-bit range
            coins = [clamp_to_width(c, DATA_WIDTH) for c in coins]
            
            # Step 1: Start computation with n and k
            dut.start.value = 1
            dut.n.value = n
            dut.k.value = k
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Step 2: Feed coins one per cycle
            for j in range(n):
                # Check if we're in PROCESS state
                if has_signal(dut, 'state'):
                    state_val = int(dut.state.value)
                    if state_val != 1:  # 1 = PROCESS
                        cocotb.log.warning(f"Expected PROCESS state, got {state_val}")
                
                dut.coin_in.value = coins[j]
                await RisingEdge(dut.clk)
            
            # Step 3: Wait for DONE state
            timeout = 0
            done = False
            while timeout < MAX_CYCLES:
                if has_signal(dut, 'state'):
                    state_val = int(dut.state.value)
                    if state_val == 2:  # DONE
                        done = True
                        break
                elif has_signal(dut, 'done'):
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                await RisingEdge(dut.clk)
                timeout += 1
            
            if not done:
                raise TestFailure(f"Timeout waiting for DONE after {timeout} cycles")
            
            # Step 4: Read result_mask and decode
            if not is_value_defined(dut.result_mask.value):
                raise TestFailure("Result mask is undefined")
            
            result_mask = int(dut.result_mask.value)
            
            # Decode the bitmask to get x values
            actual_x = []
            for x in range(k+1):
                if (result_mask >> x) & 1:
                    actual_x.append(x)
            
            # Step 5: Verify results
            if actual_x != expected_x_list:
                raise TestFailure(
                    f"Expected {expected_x_list}, got {actual_x}"
                )
            
            cocotb.log.info(f"  PASS: x values = {actual_x}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")