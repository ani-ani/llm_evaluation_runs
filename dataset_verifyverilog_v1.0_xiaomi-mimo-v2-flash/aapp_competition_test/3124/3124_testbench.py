import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Reference Python implementation for test verification
def solve_game(numbers):
    """
    Count first moves where Ivana (first player) can win.
    Returns count of winning first moves.
    """
    n = len(numbers)
    if n == 0:
        return 0
    
    # Check adjacency in circular array
    def is_adjacent(taken, new_idx):
        """Check if new_idx is adjacent to any taken index in circular array"""
        if len(taken) == 0:
            return True  # First move always valid
        for t in taken:
            if (new_idx == (t - 1) % n) or (new_idx == (t + 1) % n):
                return True
        return False
    
    # Minimax game solver
    def game_result(mask, turn, odd0, odd1):
        """
        Recursive game evaluation (converted to iterative for HDL)
        turn: 0=Ivana, 1=Zvonko
        Returns: 1=Ivana wins, -1=Zvonko wins, 0=draw
        """
        # Base case: all taken
        if mask == (1 << n) - 1:
            if odd0 > odd1:
                return 1  # Ivana wins
            elif odd1 > odd0:
                return -1  # Zvonko wins
            else:
                return 0  # Draw
        
        # Get available moves (adjacent to taken set)
        available = []
        taken_list = [i for i in range(n) if (mask >> i) & 1]
        
        for i in range(n):
            if not ((mask >> i) & 1):  # Not taken
                if is_adjacent(taken_list, i):
                    # Check oddness
                    is_odd = 1 if (numbers[i] % 2) == 1 else 0
                    new_mask = mask | (1 << i)
                    new_odd0 = odd0 + (is_odd if turn == 0 else 0)
                    new_odd1 = odd1 + (is_odd if turn == 1 else 0)
                    available.append((new_mask, turn ^ 1, new_odd0, new_odd1, is_odd))
        
        if not available:
            return 0  # No moves left
        
        # Minimax with optimal play
        if turn == 0:  # Ivana's turn (maximizer)
            best = -2
            for state in available:
                res = game_result(*state[:4])
                if res > best:
                    best = res
            return best
        else:  # Zvonko's turn (minimizer)
            best = 2
            for state in available:
                res = game_result(*state[:4])
                if res < best:
                    best = res
            return best
    
    # Count winning first moves
    win_count = 0
    for first in range(n):
        first_odd = 1 if (numbers[first] % 2) == 1 else 0
        mask = 1 << first
        result = game_result(mask, 1, first_odd, 0)
        if result == 1:  # Ivana wins
            win_count += 1
    
    return win_count

# Test cases
def generate_test_cases():
    """Generate test cases from problem examples"""
    return [
        ("3\n3 1 5\n", 3),
        ("4\n1 2 3 4\n", 2),
        ("8\n4 10 5 2 9 8 1 7\n", 5),
    ]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_circular_game(dut):
    """Test the circular game solver module"""
    
    # Clock and reset setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational circuit
        dut.rst_n.value = 1
        await Timer(100, units='ns')
    
    test_cases = generate_test_cases()
    passed = 0
    failed = 0
    
    for test_idx, (input_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx + 1}: Input parsing...")
        
        lines = input_str.strip().split('\n')
        n_val = int(lines[0])
        numbers = list(map(int, lines[1].split()))
        
        # Verify N within HDL bounds (8)
        if n_val > 8:
            cocotb.log.warning(f"N={n_val} > 8, scaling down to 8")
            n_val = 8
            numbers = numbers[:8]
        
        # Verify expected value
        expected_result = solve_game(numbers)
        cocotb.log.info(f"N={n_val}, numbers={numbers}, expected={expected_result}")
        
        # Feed inputs
        dut.n.value = n_val
        
        # Fill array (max 8 elements)
        for i in range(8):
            val = numbers[i] if i < n_val else 0
            # Check if array is structured as packed or individual signals
            if has_signal(dut, f'arr_{i}'):
                getattr(dut, f'arr_{i}').value = clamp_to_width(val, 8)
            elif has_signal(dut, 'arr'):
                try:
                    dut.arr[i].value = clamp_to_width(val, 8)
                except:
                    # Array might be packed
                    pass
            else:
                # Fallback: look for packed array
                pass
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            max_cycles = 1000
            done_seen = False
            for cycle in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_seen = True
                    break
            
            if not done_seen:
                cocotb.log.error(f"Test {test_idx + 1} FAIL: timeout")
                failed += 1
                continue
        else:
            await Timer(100, units='ns')
        
        # Read result
        if is_value_defined(dut.result.value):
            result = int(dut.result.value)
            cocotb.log.info(f"Result: {result}, Expected: {expected_result}")
            
            if result == expected_result:
                cocotb.log.info(f"Test {test_idx + 1} PASS")
                passed += 1
            else:
                cocotb.log.error(f"Test {test_idx + 1} FAIL: got {result}, expected {expected_result}")
                failed += 1
        else:
            cocotb.log.error(f"Test {test_idx + 1} FAIL: result undefined")
            failed += 1
    
    cocotb.log.info(f"\nTotal: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")