import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def wait_for_done_signal(dut, max_cycles=200):
    return cocotb.start_soon(wait_for_done(dut, max_cycles))

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Simulation Logic (Python)
def simulate_queue_elimination(values, limit=16):
    queue = list(values)
    rounds = []
    while True:
        removed = []
        next_queue = []
        to_remove = [False] * len(queue)
        
        if len(queue) == 0:
            break
            
        # Check neighbors
        for i in range(len(queue)):
            left = queue[i-1] if i > 0 else None
            right = queue[i+1] if i < len(queue)-1 else None
            
            removed_this = False
            if left is not None and left > queue[i]:
                removed_this = True
            if right is not None and right > queue[i]:
                removed_this = True
            
            to_remove[i] = removed_this
        
        # Construct next queue and record removed
        for i in range(len(queue)):
            if to_remove[i]:
                removed.append(queue[i])
            else:
                next_queue.append(queue[i])
        
        if not removed:
            break
            
        rounds.append(removed)
        queue = next_queue
        
        # Hardware limit: max 16 rounds to prevent infinite loops in simulation
        if len(rounds) >= 16:
            break
            
    return rounds, queue

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_queue_elimination(dut):
    DATA_WIDTH = 16
    ARRAY_SIZE = 16
    CLK_NS = 10
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic
        await Timer(10, units='ns')
    
    # Test Cases
    # Case 1: 10 candidates (sample 1)
    vals1 = [3, 6, 2, 3, 2, 2, 2, 1, 5, 6]
    # Case 2: 3 candidates (sample 2)
    vals2 = [17, 17, 17]
    # Case 3: 7 candidates (sample 3)
    vals3 = [8, 1, 2, 3, 5, 6, 7]
    
    test_cases = [
        (vals1, "Sample 1"),
        (vals2, "Sample 2"),
        (vals3, "Sample 3")
    ]
    
    for vals, desc in test_cases:
        # Pad inputs to 16 if necessary
        padded_vals = vals + [0] * (16 - len(vals))
        expected_rounds, expected_final = simulate_queue_elimination(vals)
        
        cocotb.log.info(f"Testing {desc}: Input {vals}")
        
        # Drive inputs
        if has_signal(dut, 'values_in'):
            for i in range(16):
                dut.values_in[i].value = clamp_to_width(padded_vals[i], DATA_WIDTH)
        elif has_signal(dut, 'values_in_0'):
             for i in range(16):
                getattr(dut, f'values_in_{i}').value = clamp_to_width(padded_vals[i], DATA_WIDTH)
                
        if has_signal(dut, 'len_in'):
            dut.len_in.value = len(vals)
        
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut, max_cycles=500)
        else:
            await Timer(100, units='ns')
            
        # Verify Results
        # 1. Check Number of Rounds
        num_rounds = int(dut.num_rounds.value)
        if num_rounds != len(expected_rounds):
             raise TestFailure(f"{desc}: Expected {len(expected_rounds)} rounds, got {num_rounds}")
             
        # 2. Check Rounds Content
        for r in range(num_rounds):
            round_count = int(dut.round_counts[r].value)
            expected_round = expected_rounds[r]
            if round_count != len(expected_round):
                 raise TestFailure(f"{desc}: Round {r} count mismatch. Expected {len(expected_round)}, got {round_count}")
            
            # Check values in the round
            # We need to handle how 'result_rounds' is accessed. 
            # Assuming it's a 2D array or accessible via index.
            for k in range(round_count):
                hw_val = 0
                # Try accessing 2D array syntax: result_rounds[r][k]
                if has_signal(dut, 'result_rounds'):
                     try:
                         hw_val = int(dut.result_rounds[r][k].value)
                     except Exception:
                         # Fallback for flattened or other structures if needed
                         pass
                # Try flattened: result_rounds_r_k
                else:
                     try:
                         hw_val = int(getattr(dut, f'result_rounds_{r}_{k}').value)
                     except Exception:
                         pass
                
                if hw_val != expected_round[k]:
                    raise TestFailure(f"{desc}: Round {r} value {k} mismatch. Expected {expected_round[k]}, got {hw_val}")

        # 3. Check Final Queue
        len_final = int(dut.len_final.value)
        if len_final != len(expected_final):
             raise TestFailure(f"{desc}: Final length mismatch. Expected {len(expected_final)}, got {len_final}")
             
        for i in range(len_final):
            hw_val = 0
            if has_signal(dut, 'result_final'):
                try:
                    hw_val = int(dut.result_final[i].value)
                except Exception:
                    pass
            else:
                try:
                    hw_val = int(getattr(dut, f'result_final_{i}').value)
                except Exception:
                    pass
                    
            if hw_val != expected_final[i]:
                raise TestFailure(f"{desc}: Final value {i} mismatch. Expected {expected_final[i]}, got {hw_val}")

        cocotb.log.info(f"{desc} Passed!")
