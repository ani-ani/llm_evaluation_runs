import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper function to convert test case format
def parse_input(input_str):
    lines = input_str.strip().split('
')
    n = int(lines[0])
    times = [int(lines[i+1]) for i in range(n)]
    return n, times

def compute_expected(n, times):
    """Compute expected result using Python algorithm"""
    if n == 0:
        return 0
    
    current_time = 0
    total_unavailable = 0
    bridge_raised = False
    
    i = 0
    while i < n:
        arrival = times[i]
        
        if not bridge_raised:
            # Bridge is down, need to raise for this boat
            # Time to raise: 60s
            # Boat passage: 20s
            # Check if we should keep raised for next boat
            
            # Calculate when we can lower
            # Boat i will pass by: current_time + 60 (raise) + 20 (pass)
            pass_end = current_time + 60 + 20
            
            # Should we wait for next boat?
            # Lower if next boat is too far away
            wait_for_next = False
            if i < n - 1:
                next_arrival = times[i+1]
                # If next boat arrives within 60s of pass_end, keep raised
                # Actually, we need to check if lowering and raising again would take longer
                # Lower takes 60, raise takes 60, total 120s overhead
                # So if next arrival - pass_end <= 120, keep raised
                if next_arrival - pass_end <= 120:
                    wait_for_next = True
            
            if wait_for_next:
                # Keep raised, serve multiple boats
                # Find how many boats we can serve in one opening
                boats_to_serve = 1
                last_pass_end = pass_end
                for j in range(i+1, n):
                    next_arr = times[j]
                    if next_arr <= last_pass_end:
                        # Boat arrived before previous finished passing
                        boats_to_serve += 1
                        last_pass_end += 20
                    else:
                        # Check if we should wait for this boat
                        gap = next_arr - last_pass_end
                        if gap <= 120:
                            boats_to_serve += 1
                            last_pass_end = next_arr + 20
                        else:
                            break
                
                # Calculate total time for this group
                raise_time = 60
                serve_time = 20 * boats_to_serve
                # Lower time is counted when we actually lower (later)
                
                total_unavailable += raise_time + serve_time
                current_time = times[i] + 60 + 20 * boats_to_serve
                i += boats_to_serve
                bridge_raised = True
            else:
                # Serve just this boat
                total_unavailable += 60 + 20
                current_time = times[i] + 60 + 20
                i += 1
                bridge_raised = False
        else:
            # Bridge is raised from previous iteration
            # Check if this boat arrived while bridge was still up
            pass
    
    return total_unavailable

def compute_expected_v2(n, times):
    """More accurate simulation"""
    current_time = 0
    total_unavailable = 0
    bridge_status = 0  # 0=down, 1=up
    
    i = 0
    while i < n:
        arrival = times[i]
        
        # Ensure current_time is at least arrival (bridge cannot move back in time)
        if current_time < arrival:
            current_time = arrival
        
        if bridge_status == 0:
            # Bridge is down, raise it
            total_unavailable += 60
            current_time += 60
            bridge_status = 1
            # After raising, boats can pass
        
        # Bridge is now up (or was already up)
        # Serve boats that are waiting or will arrive soon
        
        # Find boats to serve in this batch
        batch_end = current_time
        boats_in_batch = 0
        j = i
        
        while j < n:
            arr = times[j]
            # Boat must wait if arr < batch_end, but max wait 1800s
            # For this problem, boats are far apart, so mainly checking timing
            
            if boats_in_batch == 0:
                # First boat in batch
                if arr < batch_end:
                    # Already waiting
                    wait_time = batch_end - arr
                    if wait_time > 1800:
                        # Must have raised earlier, but we can't in this model
                        # Assuming input guarantees solvability
                        pass
                else:
                    # Arrives after batch_start
                    batch_end = arr
                batch_end += 20  # Pass time
                boats_in_batch += 1
                j += 1
            else:
                # Subsequent boats
                if arr <= batch_end:
                    # Arrived while previous boat(s) passing
                    batch_end = max(batch_end, arr) + 20
                    boats_in_batch += 1
                    j += 1
                else:
                    # Arrived after batch_end
                    gap = arr - batch_end
                    if gap <= 120:  # If gap <= 120s, cheaper to keep raised
                        batch_end = arr + 20
                        boats_in_batch += 1
                        j += 1
                    else:
                        break
        
        # Serve this batch
        if boats_in_batch > 0:
            serve_time = batch_end - current_time
            total_unavailable += serve_time
            current_time = batch_end
            i = j
            # Keep bridge up after batch
            # Check next boat
            if i < n and times[i] > current_time:
                gap = times[i] - current_time
                if gap > 120:
                    # Lower bridge
                    total_unavailable += 60
                    current_time += 60
                    bridge_status = 0
                # else keep raised
            else:
                # No more boats or next is waiting
                pass
    
    return total_unavailable

# Test with examples
print("Testing reference algorithm:")
for inp, out in [("2
100
200
", "160
"), ("3
100
200
2010
", "250
"), ("3
100
200
2100
", "300
")]:
    n, t = parse_input(inp)
    res = compute_expected_v2(n, t)
    print(f"N={n}, times={t} -> {res} (expected {out.strip()})")

@cocotb.test()
async def test_bridge_scheduler(dut):
    """Test bridge scheduler with multiple test cases"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_boats.value = 0
    for i in range(8):
        setattr(dut, f'boat_arrival_time_{i}', 0)
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {"n": 2, "times": [100, 200], "expected": 160},
        {"n": 3, "times": [100, 200, 2010], "expected": 250},
        {"n": 3, "times": [100, 200, 2100], "expected": 300},
        {"n": 1, "times": [100], "expected": 80},  # 60 raise + 20 pass
        {"n": 2, "times": [100, 110], "expected": 100},  # Close boats, serve together
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        print(f"
Test {i+1}: N={tc['n']}, times={tc['times']}, expected={tc['expected']}")
        
        # Reset for new test
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Set inputs
        dut.num_boats.value = tc['n']
        for j in range(8):
            if j < tc['n']:
                getattr(dut, f'boat_arrival_time_{j}').value = tc['times'][j]
            else:
                getattr(dut, f'boat_arrival_time_{j}').value = 0
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max ~1000 cycles for worst case)
        timeout = 2000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        result = int(dut.total_time.value)
        print(f"Result: {result}")
        
        if result == tc['expected']:
            print("PASS")
            passed += 1
        else:
            print(f"FAIL: Expected {tc['expected']}, got {result}")
    
    print(f"
--- Summary: {passed}/{total} tests passed ---")
    assert passed == total, f"Only {passed}/{total} tests passed"
