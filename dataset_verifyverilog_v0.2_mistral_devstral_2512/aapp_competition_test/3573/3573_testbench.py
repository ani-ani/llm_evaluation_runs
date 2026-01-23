import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to convert decimal to Q16.16 format
def to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper to convert Q16.16 to decimal
def from_q16_16(value):
    # Sign extend if needed
    if value & 0x80000000:
        value = value - 0x100000000
    return value / 65536.0

# Bitmask from list of numbers (1-indexed, max 16)
def card_to_mask(card_list):
    mask = 0
    for num in card_list:
        mask |= (1 << (num - 1))
    return mask

# Reference implementation in Python for verification
def compute_expected_rounds(N, D, C, cesar_list, raul_list):
    """
    Compute expected rounds using DP for small state space.
    Returns expected rounds as float.
    """
    cesar_mask = card_to_mask(caesar_list)
    raul_mask = card_to_mask(raul_list)
    
    # Get indices of cards
    cesar_indices = [i for i in range(N) if cesar_mask & (1 << i)]
    raul_indices = [i for i in range(N) if raul_mask & (1 << i)]
    
    # DP state: (c_used, r_used) where c_used is bitmask of marked cesar cards, r_used for raul
    # Since C <= 8, we can use compact indexing
    
    from math import comb
    
    # Precompute all possible draws (combinations of D balls from N)
    from itertools import combinations
    all_draws = list(combinations(range(N), D))
    total_draws = len(all_draws)
    
    # State space: 2^C for Cesar * 2^C for Raul
    # But we need mapping from their mask to compact index
    
    # Generate all possible states
    # For each player, we only care about bits that are in their card
    # So state is (c_state_mask, r_state_mask)
    
    cesar_subsets = []
    for i in range(1 << len(caesar_indices)):
        mask = 0
        for j, idx in enumerate(caesar_indices):
            if i & (1 << j):
                mask |= (1 << idx)
        cesar_subsets.append(mask)
    
    raul_subsets = []
    for i in range(1 << len(raul_indices)):
        mask = 0
        for j, idx in enumerate(raul_indices):
            if i & (1 << j):
                mask |= (1 << idx)
        raul_subsets.append(mask)
    
    # DP table: expected rounds from each state
    # Key: (c_mask, r_mask)
    # Use dictionary for sparse storage
    
    # Initialize
    dp = {}
    goal_states = set()
    
    for c_mask in cesar_subsets:
        for r_mask in raul_subsets:
            # Check if either player has all their cards
            c_complete = (c_mask == cesar_mask)
            r_complete = (r_mask == raul_mask)
            
            if c_complete or r_complete:
                dp[(c_mask, r_mask)] = 0.0
                goal_states.add((c_mask, r_mask))
            else:
                dp[(c_mask, r_mask)] = 1.0  # Initial guess
    
    # Iterative update until convergence
    # Use Gauss-Seidel style iteration
    max_iter = 1000
    tolerance = 1e-10
    
    for iteration in range(max_iter):
        max_diff = 0.0
        for c_mask in cesar_subsets:
            for r_mask in raul_subsets:
                if (c_mask, r_mask) in goal_states:
                    continue
                
                # Compute transition probabilities
                total_prob = 0.0
                new_expected = 0.0
                
                for draw in all_draws:
                    # Compute next state
                    next_c = c_mask
                    next_r = r_mask
                    
                    for ball in draw:
                        if cesar_mask & (1 << ball):
                            next_c |= (1 << ball)
                        if raul_mask & (1 << ball):
                            next_r |= (1 << ball)
                    
                    # Check if we reached a goal state
                    if (next_c, next_r) in goal_states:
                        # Add 0 for this draw (game ends, no further rounds)
                        prob = 1.0 / total_draws
                        # But we already added 1 for this round, so next state contributes 0
                    else:
                        prob = 1.0 / total_draws
                        new_expected += prob * dp[(next_c, next_r)]
                
                # E = 1 + sum(P * E_next)
                # But if all transitions lead to goal, then E = 1
                # Actually, let's do it properly:
                # If we're in state S, we play 1 round, then expected remaining is:
                # E(S) = 1 + sum_over_draws P(draw) * E(S') if S' not goal else 0
                
                # Wait, this is wrong. Let me re-derive:
                # E(S) = 1 + Σ P(draw) * E(S') for S' not goal
                # E(S') = 0 if S' is goal
                
                # So E(S) = 1 + Σ P(draw) * E(S') where S' not goal
                
                # Let's compute:
                sum_contrib = 0.0
                prob_not_goal = 0.0
                
                for draw in all_draws:
                    next_c = c_mask
                    next_r = r_mask
                    
                    for ball in draw:
                        if cesar_mask & (1 << ball):
                            next_c |= (1 << ball)
                        if raul_mask & (1 << ball):
                            next_r |= (1 << ball)
                    
                    prob = 1.0 / total_draws
                    
                    if (next_c, next_r) in goal_states:
                        # This draw ends the game, contribution is 0
                        pass
                    else:
                        sum_contrib += prob * dp[(next_c, next_r)]
                        prob_not_goal += prob
                
                # If probability of not reaching goal is 0, then E = 1
                if prob_not_goal < 1e-15:
                    new_val = 1.0
                else:
                    # We need to solve: E = 1 + Σ P * E_next
                    # But some P lead to goal (E_next = 0)
                    # So E = 1 + Σ_{non-goal} P * E_next
                    # But also, we need to account for the fact that if we reach goal,
                    # the expectation stops there.
                    # Actually the correct formula:
                    # E(S) = Σ P(draw) * (1 + E(S') if S' not goal else 0)
                    #      = Σ P(draw) * 1 + Σ P(draw) * E(S') if S' not goal
                    #      = 1 + Σ P(draw) * E(S') for S' not goal
                    
                    # Wait, that's still not right. Let's think:
                    # After 1 round, we are at S'.
                    # If S' is goal, game over, total rounds = 1.
                    # If S' is not goal, total rounds = 1 + E(S').
                    # So E(S) = Σ P * (1 if goal else 1 + E(S'))
                    #         = Σ P * 1 + Σ_{not goal} P * E(S')
                    #         = 1 + Σ_{not goal} P * E(S')
                    # But this is only if we know E(S') for non-goal states.
                    # This is a system of linear equations.
                    
                    # Let's use Gauss-Seidel properly:
                    # E_new = 1 + Σ_{not goal} P * E_old
                    # But we need to handle the goal states correctly.
                    
                    # Actually, if P_goal is the probability of reaching goal in one step:
                    # E(S) = P_goal * 1 + (1-P_goal) * (1 + E_avg)
                    # This is wrong too.
                    
                    # Correct approach:
                    # E(S) = Σ P(draw) * T(draw)
                    # where T(draw) = 1 if draw leads to goal
                    #              = 1 + E(S') if draw leads to S' not goal
                    # So E(S) = Σ P * (1 + (1-goal) * E(S'))
                    #         = 1 + Σ_{not goal} P * E(S')
                    
                    # So the update is:
                    # E_new(S) = 1 + Σ_{S' not goal} P(S->S') * E_old(S')
                    
                    # But we need to solve for all S simultaneously.
                    # Using value iteration:
                    # Start with E=0 for all states, iterate until convergence.
                    # But for goal states, E=0.
                    # For non-goal: E = 1 + Σ P * E_next
                    # But E_next might be goal (0) or non-goal.
                    
                    # So the formula is correct: E = 1 + Σ P * E_next
                    # where E_next = 0 for goal states.
                    
                    new_val = 1.0 + sum_contrib
                
                diff = abs(new_val - dp[(c_mask, r_mask)])
                if diff > max_diff:
                    max_diff = diff
                
                dp[(c_mask, r_mask)] = new_val
        
        if max_diff < tolerance:
            break
    
    # Return expected rounds from initial state
    return dp[(0, 0)]

@cocotb.test()
async def test_betting_game(dut):
    """Test betting game expected rounds calculation"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N_in.value = 0
    dut.D_in.value = 0
    dut.C_in.value = 0
    dut.cesar_card.value = 0
    dut.raul_card.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Simple 2-ball case
    dut._log.info("Test 1: N=2, D=1, C=1")
    dut.N_in.value = 2
    dut.D_in.value = 1
    dut.C_in.value = 1
    dut.cesar_card.value = card_to_mask([1])  # Bit 0
    dut.raul_card.value = card_to_mask([2])   # Bit 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 100000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100000:
        raise TestFailure("Test 1: Timeout - computation did not finish")
    
    if not dut.valid.value:
        raise TestFailure("Test 1: Valid signal not high when done")
    
    result = dut.result.value
    expected = to_q16_16(1.0)
    result_dec = from_q16_16(int(result))
    expected_dec = 1.0
    
    dut._log.info(f"Test 1 Result: {result_dec:.8f} (Q16.16: {result})")
    dut._log.info(f"Test 1 Expected: {expected_dec:.8f} (Q16.16: {expected})")
    
    error = abs(result_dec - expected_dec)
    if error > 0.001:
        raise TestFailure(f"Test 1: Error {error:.8f} > 0.001")
    
    # Wait a few cycles before next test
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 2: Medium case
    dut._log.info("Test 2: N=4, D=2, C=2")
    dut.N_in.value = 4
    dut.D_in.value = 2
    dut.C_in.value = 2
    dut.cesar_card.value = card_to_mask([1, 2])  # Bits 0,1
    dut.raul_card.value = card_to_mask([3, 4])   # Bits 2,3
    
    # Expected value for this case (computed by reference)
    # This requires computing the expected value
    # For N=4, D=2, C=2, Cesar={1,2}, Raul={3,4}
    # Each round draws 2 balls
    # Probability of Cesar winning in round 1: drawing {1,2} = 1/6
    # Probability of Raul winning in round 1: drawing {3,4} = 1/6
    # Probability of tie/draw in round 1: drawing one from each = 4/6 = 2/3
    # If tie, we continue
    # This requires full DP
    
    # Let's use a simpler test case where we know the answer
    # N=3, D=1, C=1, Cesar={1}, Raul={2}, third ball 3
    # Each round: pick 1 ball
    # P(Cesar wins) = 1/3
    # P(Raul wins) = 1/3
    # P(no winner) = 1/3
    # If no winner, continue from same state
    # E = (1/3)*1 + (1/3)*1 + (1/3)*(1+E)
    # E = 2/3 + (1/3) + (1/3)E
    # E = 1 + E/3
    # E - E/3 = 1
    # (2/3)E = 1
    # E = 1.5
    
    dut._log.info("Test 2: N=3, D=1, C=1")
    dut.N_in.value = 3
    dut.D_in.value = 1
    dut.C_in.value = 1
    dut.cesar_card.value = card_to_mask([1])
    dut.raul_card.value = card_to_mask([2])
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100000:
        raise TestFailure("Test 2: Timeout")
    
    if not dut.valid.value:
        raise TestFailure("Test 2: Valid not high")
    
    result = dut.result.value
    expected = to_q16_16(1.5)
    result_dec = from_q16_16(int(result))
    expected_dec = 1.5
    
    dut._log.info(f"Test 2 Result: {result_dec:.8f}")
    dut._log.info(f"Test 2 Expected: {expected_dec:.8f}")
    
    error = abs(result_dec - expected_dec)
    if error > 0.001:
        raise TestFailure(f"Test 2: Error {error:.8f} > 0.001")
    
    # Test case 3: 4 balls, 2 drawn, 1 card each, overlapping
    # N=4, D=2, Cesar={1}, Raul={1,2}
    # Let's compute expected
    # Probability Cesar wins round 1: drawing ball 1 = 2/6 (any pair containing 1)
    # Actually P(1 in {2 balls}) = C(3,1)/C(4,2) = 3/6 = 0.5
    # P(Raul wins round 1): needs both 1 and 2 = 1/6
    # P(no winner): rest = 1 - 0.5 - 1/6 = 1/3
    # Wait, if Cesar gets 1, he wins. If Raul gets 1 and 2, he wins.
    # These are not disjoint! If both 1 and 2 are drawn, Raul wins.
    # So P(Cesar wins) = P(1 drawn, not both 1,2) = P(1 drawn) - P(1,2 drawn) = 3/6 - 1/6 = 2/6 = 1/3
    # P(Raul wins) = P(1,2 drawn) = 1/6
    # P(continue) = 1 - 1/3 - 1/6 = 1/2
    # E = 1/3*1 + 1/6*1 + 1/2*(1+E) = 0.5 + 0.5 + 0.5E = 1 + 0.5E
    # E - 0.5E = 1 => E = 2.0
    
    dut._log.info("Test 3: N=4, D=2, C=1 for Cesar, C=2 for Raul")
    dut.N_in.value = 4
    dut.D_in.value = 2
    dut.C_in.value = 1  # This is size, but we can use different cards
    # To make it work with the module spec, let's use C=2 for both but Cesar only uses 1
    # Actually let's just test: N=4, D=2, Cesar={1}, Raul={1}
    # Both want 1. First to get it wins.
    # P(1 drawn) = 3/6 = 0.5
    # E = 0.5*1 + 0.5*(1+E)
    # E = 0.5 + 0.5 + 0.5E = 1 + 0.5E
    # E = 2.0
    
    dut._log.info("Test 3: N=4, D=2, both want ball 1")
    dut.N_in.value = 4
    dut.D_in.value = 2
    dut.C_in.value = 1
    dut.cesar_card.value = card_to_mask([1])
    dut.raul_card.value = card_to_mask([1])
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100000:
        raise TestFailure("Test 3: Timeout")
    
    if not dut.valid.value:
        raise TestFailure("Test 3: Valid not high")
    
    result = dut.result.value
    expected = to_q16_16(2.0)
    result_dec = from_q16_16(int(result))
    expected_dec = 2.0
    
    dut._log.info(f"Test 3 Result: {result_dec:.8f}")
    dut._log.info(f"Test 3 Expected: {expected_dec:.8f}")
    
    error = abs(result_dec - expected_dec)
    if error > 0.001:
        raise TestFailure(f"Test 3: Error {error:.8f} > 0.001")
    
    # Summary
    dut._log.info("All tests passed!")

# Additional test function for computing reference values
def compute_reference(N, D, cesar_list, raul_list):
    """
    Compute expected rounds using DP.
    Returns float.
    """
    from itertools import combinations
    from math import comb
    
    cesar_mask = 0
    for c in cesar_list:
        cesar_mask |= (1 << (c-1))
    
    raul_mask = 0
    for r in raul_list:
        raul_mask |= (1 << (r-1))
    
    all_balls = set(range(N))
    all_draws = list(combinations(range(N), D))
    total_draws = len(all_draws)
    
    # States: (c_mask, r_mask) where masks are over all N balls
    # But we only need to store states where some bits are set
    # Use DP with convergence
    
    # Get full state space (sparse)
    # We need all combinations of subsets of cesar_mask and raul_mask
    from itertools import product, chain, combinations as combo
    
    def powerset(iterable):
        s = list(iterable)
        return chain.from_iterable(combo(s, r) for r in range(len(s)+1))
    
    cesar_bits = [i for i in range(N) if cesar_mask & (1 << i)]
    raul_bits = [i for i in range(N) if raul_mask & (1 << i)]
    
    cesar_states = []
    for subset in powerset(caesar_bits):
        mask = 0
        for bit in subset:
            mask |= (1 << bit)
        cesar_states.append(mask)
    
    raul_states = []
    for subset in powerset(raul_bits):
        mask = 0
        for bit in subset:
            mask |= (1 << bit)
        raul_states.append(mask)
    
    # Map state to index
    state_to_idx = {}
    idx = 0
    goal_indices = []
    
    for c in cesar_states:
        for r in raul_states:
            state_to_idx[(c, r)] = idx
            if (c == cesar_mask) or (r == raul_mask):
                goal_indices.append(idx)
            idx += 1
    
    num_states = idx
    
    # Precompute transition matrix P where P[i][j] = prob from state i to j
    # And reward vector b where b[i] = 1 for non-goal states
    # Then solve E = P*E + b
    
    # Instead of matrix inversion, use value iteration
    E = [0.0] * num_states
    for i in range(num_states):
        if i in goal_indices:
            E[i] = 0.0
        else:
            E[i] = 1.0
    
    for iteration in range(1000):
        max_diff = 0.0
        for i in range(num_states):
            if i in goal_indices:
                continue
            
            # Get state from i
            c_mask, r_mask = None
            for (c, r), idx in state_to_idx.items():
                if idx == i:
                    c_mask, r_mask = c, r
                    break
            
            # Compute sum over draws
            sum_val = 0.0
            for draw in all_draws:
                next_c = c_mask
                next_r = r_mask
                for ball in draw:
                    if cesar_mask & (1 << ball):
                        next_c |= (1 << ball)
                    if raul_mask & (1 << ball):
                        next_r |= (1 << ball)
                
                j = state_to_idx[(next_c, next_r)]
                sum_val += E[j]
            
            new_E = 1.0 + sum_val / total_draws
            diff = abs(new_E - E[i])
            if diff > max_diff:
                max_diff = diff
            E[i] = new_E
        
        if max_diff < 1e-10:
            break
    
    # Initial state is (0, 0)
    init_idx = state_to_idx[(0, 0)]
    return E[init_idx]

# Precompute expected values for our test cases
def compute_test_values():
    print("Test case values:")
    
    # Test 1: N=2, D=1, Cesar={1}, Raul={2}
    val1 = compute_reference(2, 1, [1], [2])
    print(f"Test 1: {val1:.8f} (expected 1.0)")
    
    # Test 2: N=3, D=1, Cesar={1}, Raul={2}
    val2 = compute_reference(3, 1, [1], [2])
    print(f"Test 2: {val2:.8f} (expected 1.5)")
    
    # Test 3: N=4, D=2, Cesar={1}, Raul={1}
    val3 = compute_reference(4, 2, [1], [1])
    print(f"Test 3: {val3:.8f} (expected 2.0)")
    
    # Test 4: N=4, D=2, Cesar={1,2}, Raul={3,4}
    val4 = compute_reference(4, 2, [1,2], [3,4])
    print(f"Test 4: {val4:.8f}")

if __name__ == "__main__":
    compute_test_values()
