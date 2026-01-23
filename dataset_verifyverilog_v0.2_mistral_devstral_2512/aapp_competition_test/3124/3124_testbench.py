import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def solve_game(numbers):
    """Solve the game for small N (≤8) using DP with memoization"""
    N = len(numbers)
    # Convert to odd/even bits
    bits = [(x % 2) for x in numbers]
    
    # Memoization: (mask, player) -> (best_outcome_diff, count_odd_taken)
    # player 0 = Ivana (maximizing), 1 = Zvonko (minimizing)
    memo = {}
    
    def get_taken_indices(mask):
        return [i for i in range(N) if mask & (1 << i)]
    
    def get_available_moves(mask, taken_indices):
        """Returns list of indices that can be taken"""
        if not taken_indices:
            return list(range(N))  # First move can be any
        
        available = []
        # Adjacent to any taken index
        for idx in taken_indices:
            left = (idx - 1) % N
            right = (idx + 1) % N
            if not (mask & (1 << left)):
                available.append(left)
            if not (mask & (1 << right)):
                available.append(right)
        return list(set(available))
    
    def evaluate_state(mask, player, taken_indices):
        """Return (outcome_diff, count_odd_taken_by_current_player)"""
        state_key = (mask, player)
        if state_key in memo:
            return memo[state_key]
        
        available = get_available_moves(mask, taken_indices)
        if not available:
            # Terminal state - count final scores
            ivana_odd = 0
            zvonko_odd = 0
            # Reconstruct: even indices go to Ivana, odd to Zvonko
            move_order = []
            temp_mask = mask
            # Can't reconstruct exact move order, so use parity of move count
            # Actually need to track who took what
            # Simpler: use recursion to track counts
            # For terminal, just return diff from accumulated
            # Since we can't track full history, return diff based on final counts
            # Let's rebuild: use recursion to build full tree
            # For simplicity in this test function, we'll use a different approach
            return (0, 0)  # This will be handled in full eval
        
        outcomes = []
        for move in available:
            new_mask = mask | (1 << move)
            new_taken = taken_indices + [move]
            # Check if terminal
            if len(new_taken) == N:
                # Calculate final result
                # Need to know which player took each index
                # We need to track move history
                # Let's rewrite with full tracking
                pass
        
        memo[state_key] = (0, 0)
        return (0, 0)
    
    # Full recursive evaluation with move tracking
    def evaluate_full(mask, player, moves_history):
        """Full evaluation tracking who took what
           Returns (outcome_diff, is_valid) 
           where outcome_diff = Ivana_odd - Zvonko_odd
        """
        available = get_available_moves(mask, [idx for idx, _ in moves_history])
        
        if not available:
            # Terminal - count scores
            ivana_odd = 0
            zvonko_odd = 0
            for idx, who in moves_history:
                if bits[idx] == 1:
                    if who == 0:  # Ivana
                        ivana_odd += 1
                    else:  # Zvonko
                        zvonko_odd += 1
            return (ivana_odd - zvonko_odd, True)
        
        results = []
        for move in available:
            new_moves = moves_history + [(move, player)]
            new_mask = mask | (1 << move)
            next_player = 1 - player
            outcome, valid = evaluate_full(new_mask, next_player, new_moves)
            results.append(outcome)
        
        if player == 0:  # Ivana maximizes
            best = max(results)
        else:  # Zvonko minimizes
            best = min(results)
        
        return (best, True)
    
    # Count valid first moves
    count = 0
    for first_move in range(N):
        mask = 1 << first_move
        moves_history = [(first_move, 0)]  # Ivana took first
        outcome, _ = evaluate_full(mask, 1, moves_history)  # Zvonko's turn
        if outcome > 0:  # Ivana wins
            count += 1
    
    return count

@cocotb.test()
async def test_ivana_game_solver(dut):
    """Test the Ivana Game Solver module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_bits.value = 0
    dut.N.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([3, 1, 5], 3),
        ([1, 2, 3, 4], 2),
        ([4, 10, 5, 2, 9, 8, 1, 7], 5),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for numbers, expected in test_cases:
        N = len(numbers)
        # Pack odd/even bits into num_bits
        num_bits = 0
        for i, num in enumerate(numbers):
            if num % 2 == 1:
                num_bits |= (1 << i)
        
        print(f"Test case: N={N}, numbers={numbers}, bits=0b{num_bits:b}")
        
        # Start computation
        dut.num_bits.value = num_bits
        dut.N.value = N
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 3000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TimeoutError("Module did not complete in time")
        
        result = int(dut.result.value)
        print(f"  Expected: {expected}, Got: {result}")
        
        if result == expected:
            passed += 1
        else:
            print(f"  FAILED!")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
