import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper to convert array to inputs
def generate_stimulus(arr, q):
    # We need to simulate the reverse processing logic for the testbench reference
    n = len(arr)
    zeros = []
    last = {}
    cur_max = 0
    stack = []
    result = arr.copy()
    
    # Find last positions and zeros
    for i in range(n-1, -1, -1):
        if arr[i] == 0:
            zeros.append(i)
        elif arr[i] not in last:
            last[arr[i]] = i
            
    # Process forward to fill array
    stack = []
    cur_max = 0
    possible = True
    
    for i in range(n):
        if arr[i] == 0:
            result[i] = max(cur_max, 1)
        elif arr[i] > cur_max and last[arr[i]] != i:
            stack.append(cur_max)
            cur_max = arr[i]
        elif cur_max != 0 and i == last[cur_max]:
            if stack:
                cur_max = stack.pop()
            else:
                cur_max = 0
        elif arr[i] < cur_max:
            possible = False
            break
        result[i] = result[i] if arr[i] == 0 else arr[i]
            
    if not possible:
        return None, False
        
    # Check Q constraint
    max_val = max(result)
    if q > max_val:
        if zeros:
            # Set first zero (in result order) to q
            for z in zeros:
                result[z] = q
                break
        else:
            return None, False
    elif q < max_val:
        return None, False
        
    return result, True

@cocotb.test()
async def test_array_reconstructor(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.valid_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled down to N=16, Q=32)
    test_cases = [
        ([1, 0, 2, 3], 3),
        ([10, 10, 10], 10),
        ([6, 5, 6, 2, 2], 6), # Should fail
        ([0, 0, 0], 5),
        ([1, 1, 1, 5, 5], 5),
        ([5, 0, 0, 4, 4], 5),
        ([2, 1, 3, 2], 3), # Should fail
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr, q_val in test_cases:
        n = len(arr)
        if n > 16 or q_val > 32:
            print(f"Skipping test {arr} (exceeds bounds)")
            total -= 1
            continue
            
        # Expected result
        exp_result, exp_possible = generate_stimulus(arr, q_val)
        
        # Stimulate DUT
        # 1. Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 2. Feed data (we need to feed it in order, but DUT processes reverse?
        # The prompt says 'In each cycle valid_in high: process current element'
        # Let's assume we feed N values sequentially.
        # To match the logic, we should probably feed N->1 order if DUT is reverse-oriented.
        # Or simpler: Feed 1->N order but DUT internal logic handles index decrement.
        # Let's feed 1->N order as 'data_in', and DUT should handle the rest.
        
        # However, the logic requires knowing 'last occurrence' of values.
        # This implies a PRE-PASS or two-pass logic.
        # Given the prompt constraint of a sequential module, we assume a single pass is complex.
        # Let's try a single pass where we feed the array normally, but DUT is expected to
        # reconstruct the state. 
        
        # Revised Stimulus for Single Pass:
        # We feed indices 0 to N-1. DUT must buffer or process on fly.
        # Wait, the algorithm in Python does a reverse scan first to find last indices.
        # A pure hardware stream processor cannot know future indices.
        # So we must feed the array TWICE, or feed it reversed.
        # Let's feed it REVERSED (index N-1 down to 0) so we encounter last occurrences first.
        
        # Reset stack for this test
        dut.data_in.value = 0
        dut.valid_in.value = 0
        
        # Wait for IDLE state (assuming done goes high)
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        # Start again
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed reversed array
        received_results = []
        error_flag = False
        
        # Reverse iteration for feed
        for val in reversed(arr):
            dut.data_in.value = val
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
            # Capture output (assuming output appears with latency 1)
            if dut.valid_out.value:
                received_results.append(int(dut.result_out.value))
            if dut.error.value:
                error_flag = True
                break
            
        # Wait for completion
        for _ in range(5):
            await RisingEdge(dut.clk)
            if dut.valid_out.value:
                received_results.append(int(dut.result_out.value))
            if dut.error.value:
                error_flag = True
                
        # Check Results
        if exp_possible:
            if not error_flag:
                # We collected results in reverse (N-1 to 0), reverse back to compare
                # Or verify directly
                # Python exp_result is 0..N-1
                # Hardware results (if pipelined) might be in reverse order or need reordering.
                # Assuming hardware outputs match the processing order (reverse).
                # So received_results is [val_at_N-1, val_at_N-2, ..., val_at_0]
                
                # Match with exp_result reversed
                rev_exp = list(reversed(exp_result))
                
                # Compare only the first N values (ignore extras)
                match = True
                if len(received_results) < len(rev_exp):
                    match = False
                else:
                    for i in range(len(rev_exp)):
                        # Special handling for Q > max_val case
                        # The Python script sets the FIRST zero to Q.
                        # In hardware, if we feed reversed, we might encounter that zero.
                        # Let's just check if the array is valid.
                        if received_results[i] != rev_exp[i]:
                            # Check if it's the special Q case
                            if q_val > max(arr) and 0 in arr:
                                # The zero becomes Q. But which zero? Python picks first in forward order.
                                # In reverse order, it's the LAST zero.
                                # So hardware logic might differ. 
                                # Let's relax strict equality for this specific case if types match.
                                # Or better: re-run python logic to match hardware order.
                                
                                # Actually, let's assume hardware assigns Q to the LAST zero encountered in reverse scan
                                # (which is the first zero in forward scan).
                                pass
                            
                            # Strict check
                            if received_results[i] != rev_exp[i]:
                                match = False
                                break
                
                if match:
                    passed += 1
                    print(f"Test Passed: {arr}")
                else:
                    print(f"Test Failed: {arr}. Expected {exp_result}, Got {list(reversed(received_results))}")
            else:
                print(f"Test Failed: {arr}. Expected YES, Got Error")
        else:
            if error_flag:
                passed += 1
                print(f"Test Passed (Correctly Failed): {arr}")
            else:
                print(f"Test Failed: {arr}. Expected NO, Got Yes")
                
    print(f"
Summary: {passed}/{total} tests passed")
