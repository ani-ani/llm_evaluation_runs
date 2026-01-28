import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def check_all_same(state):
    return state == 0 or state == 0xFF

def simulate_move(state, k, player):
    """Simulate optimal move: player 0 (Toki) flips to 0, player 1 (Quailty) flips to 1"""
    new_state = state
    for i in range(min(k, 8)):
        new_state = (new_state & ~(1 << i)) | ((player & 1) << i)
    return new_state

def check_win(state, k):
    """Check if current player can win in one move"""
    for i in range(9 - k):
        # Try flipping to 0
        test = state
        for j in range(k):
            test &= ~(1 << (i + j))
        if test == 0 or test == 0xFF:
            return True
        # Try flipping to 1
        test = state
        for j in range(k):
            test |= (1 << (i + j))
        if test == 0 or test == 0xFF:
            return True
    return False

def has_cycle(state, history):
    return state in history

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_duel_game(dut):
    """Test the duel game module with multiple test cases"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (initial_state, k, expected_result, description)
    # Results: 0=Tokitsukaze, 1=Quailty, 2=Once again
    test_cases = [
        # Original test cases adapted to n=8
        (0b01010101, 2, 1, "4 2 0101 -> quailty"),
        (0b01010101, 1, 2, "6 1 010101 -> once again"),
        (0b01010101, 5, 0, "6 5 010101 -> tokitsukaze"),
        (0b00110000, 1, 2, "4 1 0011 -> once again"),
        # Additional test cases
        (0b11111111, 1, 0, "Already all 1s"),
        (0b00000000, 1, 0, "Already all 0s"),
        (0b11111110, 1, 0, "Almost all 1s"),
        (0b11111110, 2, 0, "Flip last two to 1"),
        (0b10101010, 4, 0, "Flip middle 4 to 0"),
        (0b11100111, 3, 1, "Needs careful play"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (initial_state, k, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        # Reset for each test
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Set inputs
        dut.initial_state.value = initial_state
        dut.k.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined")
        
        actual = int(dut.result.value)
        expected_result = expected
        
        if actual == expected_result:
            dut._log.info(f"  PASS: got {actual}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: expected {expected_result}, got {actual}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")