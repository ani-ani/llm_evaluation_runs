import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

# Constants
N = 8
T = 4
SCALE = 65536  # 2^16 for Q16.16

# Test Data: (drop_time, type, fill_time)
# Type: 0=Remote, 1=In-store
test_data_1 = [
    (1, 0, 4),
    (2, 0, 2),
    (3, 0, 2),
    (4, 1, 2),
    (5, 1, 1)
]

test_data_2 = [
    (1, 0, 4),
    (2, 0, 2),
    (3, 0, 2),
    (4, 1, 2),
    (5, 1, 1)
]

def to_q1616(val):
    return int(val * SCALE)

def to_float(q_val):
    return q_val / SCALE

async def run_test(dut, test_data, num_technicians):
    # Setup inputs
    dut.start.value = 0
    dut.rst_n.value = 0
    dut.valid_count.value = len(test_data)
    
    # Initialize arrays with 0
    for i in range(N):
        dut.in_drop_time[i].value = 0
        dut.in_type[i].value = 0
        dut.in_fill_time[i].value = 0
        
    # Load data
    for i, (drop, typ, fill) in enumerate(test_data):
        dut.in_drop_time[i].value = to_q1616(drop)
        dut.in_type[i].value = typ
        dut.in_fill_time[i].value = to_q1616(fill)
        
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while not dut.done.value and cycles < 5000:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if cycles >= 5000:
        raise TestFailure("Simulation timed out")
        
    # Check results
    avg_in = to_float(int(dut.avg_in_store_time.value))
    avg_rem = to_float(int(dut.avg_remote_time.value))
    
    return avg_in, avg_rem

@cocotb.test()
async def test_pharmacy_case1(dut):
    """Test Case 1: 5 scripts, 3 techs -> In: 1.5, Rem: 2.666667"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Expected results
    # In-store: (5.0-4.0)/2 + (5.0-5.0)/2? No.
    # Sim logic:
    # T=0: Pick S(4,2), R(1,4), R(2,2). [Waiting: R(3,2)].
    # Finishes: R(1,4)@4, S(4,2)@6, R(2,2)@6.
    # T=4: Pick R(3,2). Finishes@6.
    # In-store sum: (6-4) + (6-5) = 2 + 1 = 3. Count 2. Avg 1.5.
    # Remote sum: (4-1) + (6-2) + (6-3) = 3 + 4 + 3 = 10. Count 3. Avg 3.333... wait.
    # Wait, let's re-verify Sample Output 1: 1.500000 2.666667
    # Maybe I calculated wrong.
    # T=0: R(1,4) starts, R(2,2) starts, R(3,2) starts. (In-store not yet arrived).
    # T=1: S(4,2) arrives. Wait for R to finish.
    # T=4: R(1,4) finishes. S(4,2) starts. R(2,2) finishes. R(3,2) finishes.
    # T=5: S(5,1) arrives.
    # T=6: S(4,2) finishes. S(5,1) starts.
    # T=7: S(5,1) finishes.
    # 
    # In-store:
    # S(4,2): Start 4, End 6. Comp = 2.
    # S(5,1): Start 6, End 7. Comp = 2. (Wait 1s).
    # Avg = (2+2)/2 = 2.0.  <-- Sample says 1.5.
    # 
    # Let's look at the rule: "technicians will not start filling remote prescriptions as long as there are in-store prescriptions to be filled."
    # This implies that if an in-store is WAITING (even if not yet arrived?), wait.
    # No, "as long as there are in-store prescriptions to be filled" implies in the queue.
    # 
    # Re-read Sample 1:
    # 5 3
    # 1 R 4
    # 2 R 2
    # 3 R 2
    # 4 S 2
    # 5 S 1
    # Output: 1.5 2.666667
    # 
    # Let's try to reverse engineer 1.5.
    # If In-store total is 3.0 (3/2=1.5).
    # S(4,2): Comp = X
    # S(5,1): Comp = Y
    # X + Y = 3.0.
    # 
    # If we assume strict priority:
    # T=0: R(1,4), R(2,2), R(3,2). 
    # T=4: R(1,4) finishes. S(4,2) arrives. Techs are busy? Yes, R(2,2) and R(3,2) are busy.
    # Wait, T=2: R(2,2) finishes. 
    # T=3: R(3,2) finishes.
    # 
    # Maybe the sample assumes that if you have 3 techs, and 3 R arrive at 1,2,3, they start immediately.
    # R(1,4) -> T1. R(2,2) -> T2. R(3,2) -> T3. 
    # S(4,2) arrives at 4. Must wait for one tech.
    # Earliest finish: T2 finishes at 2+2=4. T3 finishes at 3+2=5. T1 finishes at 1+4=5.
    # So S(4,2) starts at 4, finishes at 6. Comp=2.
    # S(5,1) arrives at 5. Techs busy (T1 busy till 5, T2 free at 4 (but occupied by S), T3 busy till 5).
    # So S(5,1) waits for T3 at 5. Starts at 5, ends at 6. Comp=1.
    # Total In-store = 3. Avg = 1.5. Matches.
    # 
    # Remote:
    # R(1,4): Start 1, End 5. Comp=4.
    # R(2,2): Start 2, End 4. Comp=2.
    # R(3,2): Start 3, End 5. Comp=2.
    # Total Remote = 8. Avg = 2.6666. Matches.
    
    # So the logic is: 
    # 1. Always pick In-store if available.
    # 2. If no In-store, pick Remote.
    # 3. Pick earliest available technician.
    
    avg_in, avg_rem = await run_test(dut, test_data_1, 3)
    
    if abs(avg_in - 1.5) > 0.001 or abs(avg_rem - 2.666667) > 0.001:
        raise TestFailure(f"Case 1 failed. Got {avg_in:.6f} {avg_rem:.6f}")

@cocotb.test()
async def test_pharmacy_case2(dut):
    """Test Case 2: 5 scripts, 2 techs -> In: 1.5, Rem: 3.666667"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Expected logic:
    # 2 Techs.
    # T=0: R(1,4), R(2,2).
    # T=2: R(2,2) finishes. R(3,2) starts (since S not arrived yet).
    # T=4: R(1,4) finishes. S(4,2) arrives. Starts immediately.
    # T=5: S(5,1) arrives. Techs: T1 busy (S), T2 busy (R(3,2) until 5).
    # T=5: R(3,2) finishes. S(5,1) starts immediately.
    # T=6: S(4,2) finishes.
    # T=6: S(5,1) finishes.
    # 
    # In-store:
    # S(4,2): Start 4, End 6. Comp=2.
    # S(5,1): Start 5, End 6. Comp=1. 
    # Total 3. Avg 1.5. Matches.
    # 
    # Remote:
    # R(1,4): Start 1, End 5. Comp=4.
    # R(2,2): Start 0, End 2. Comp=2.
    # R(3,2): Start 2, End 5. Comp=3.
    # Total 9. Avg 3.0. 
    # Wait, Sample Output 2 says 3.666667.
    # Let's re-check R(3,2).
    # T=0: R(1,4) on T1, R(2,2) on T2.
    # T=2: T2 finishes R(2,2). R(3,2) arrives. No S yet. R(3,2) starts on T2 at T=2.
    # R(3,2) duration 2 -> Finishes at T=4.
    # T=4: R(1,4) finishes on T1. R(3,2) finishes on T2. S(4,2) arrives. 
    # S(4,2) starts on T2 at T=4. Finishes T=6. Comp=2.
    # T=5: S(5,1) arrives. T1 is free (finished R1). S(5,1) starts on T1 at T=5. Finishes T=6. Comp=1.
    # 
    # Remote Summary:
    # R(1,4): Start 1, End 5. Wait 0. Comp=4.
    # R(2,2): Start 0, End 2. Wait 0. Comp=2.
    # R(3,2): Start 2, End 4. Wait 0. Comp=2.
    # Total 8. Avg 2.66667. 
    # 
    # Why Sample Output 2 is 3.666667?
    # Maybe the rule "technicians will not start filling remote prescriptions as long as there are in-store prescriptions to be filled"
    # applies strictly? 
    # 
    # Let's re-read carefully.
    # "technicians will not start filling remote prescriptions as long as there are in-store prescriptions to be filled."
    # In Sample 1, S(4,2) arrives at 4. At that moment R(2,2) and R(3,2) are active (started before S arrived).
    # So they finish. 
    # In Sample 2, 2 techs.
    # T=0: R(1,4) starts. R(2,2) starts.
    # T=2: R(2,2) finishes. Is there an In-store? No (S arrives at 4). So R(3,2) starts.
    # T=4: R(1,4) finishes, R(3,2) finishes. S(4,2) arrives. S starts.
    # T=5: S(5,1) arrives. T1 (R1 finished) free. S starts.
    # T=6: S(4,2) finishes, S(5,1) finishes.
    # 
    # This gives 2.6666 for remote. 
    # 
    # Let's try to get 3.6666 for remote.
    # That means Total Remote = 11.
    # 11 / 3 = 3.6666.
    # Distances: 4, 2, 5? 4+2+5=11.
    # How to get R(3,2) comp=5?
    # R(3,2) must wait 3s.
    # 
    # Maybe I misunderstood the policy.
    # "technicians will not start filling remote prescriptions as long as there are in-store prescriptions to be filled."
    # 
    # Let's look at the inputs again.
    # 1 R 4
    # 2 R 2
    # 3 R 2
    # 4 S 2
    # 5 S 1
    # 
    # Maybe the order of input matters if times are equal? "multiple prescriptions may be dropped off at the same time, in which case preference should be given to any in-store prescriptions, regardless of the order in which they appear in the input."
    # 
    # Let's try to find a scenario that matches Sample 2.
    # Maybe if S(4,2) starts, it blocks new R from starting even if S hasn't arrived yet?
    # No, "as long as there are in-store prescriptions to be filled" means in the queue.
    # 
    # Wait, what if the state machine logic is:
    # If NO technicians are free, do nothing.
    # If technicians are free:
    #   If Queue has In-Store -> Start In-Store.
    #   Else if Queue has Remote -> Start Remote.
    # 
    # Sample 2: 2 Techs.
    # T=0: R1(1,4), R2(2,2).
    # T=2: R2 finishes. Queue: R3(3,2). No S. Start R3.
    # T=4: R1 finishes (at 1+4=5? No, 1+4=5). R3 finishes (2+2=4). 
    # Wait, R1 started at 0, duration 4 -> Ends 4.
    # R2 started at 0, duration 2 -> Ends 2.
    # R3 started at 2, duration 2 -> Ends 4.
    # 
    # T=4: R1 ends, R3 ends. S(4,2) arrives. Start S on T1.
    # T=5: S(5,1) arrives. T2 is free (R3 finished). Start S on T2.
    # 
    # Okay, I am confident in my logic. The sample outputs provided in the prompt might have a specific interpretation of "In-store prescriptions to be filled".
    # 
    # Hypothesis: "In-store prescriptions to be filled" includes those that have arrived AND those that are *waiting* to arrive? No.
    # 
    # Let's check the output for Sample 2 again.
    # Output: 1.500000 3.666667
    # If Remote is 3.666667, sum is 11.
    # If R(3,2) is 5, it waited 3s.
    # When did it wait? It arrived at 3.
    # It could only wait if it wasn't picked up at 3.
    # 
    # Maybe the rule is: "technicians will not start filling remote prescriptions as long as there are in-store prescriptions to be filled."
    # But what if an In-store prescription is DROPPED OFF while a Remote is waiting?
    # 
    # Let's look at the time line for Sample 2 again, maybe I messed up durations.
    # T1: Tech 1. T2: Tech 2.
    # Time 1: R(1,4) arrives. T1 starts it.
    # Time 2: R(2,2) arrives. T2 starts it.
    # Time 3: R(3,2) arrives. No techs free. Wait.
    # Time 4: R(2,2) finishes (2+2). R(3,2) is waiting. S(4,2) arrives.
    #     Now, queue has R(3,2) and S(4,2).
    #     Rule: In-store first. S(4,2) starts on T2 (just freed).
    # Time 5: R(1,4) finishes (1+4). S(5,1) arrives.
    #     Queue: S(5,1). 
    #     T1 is free. S(5,1) starts on T1.
    # Time 6: S(4,2) finishes (4+2). S(5,1) finishes (5+1).
    # 
    # Remote Times:
    # R(1,4): Start 1, End 5. Comp 4.
    # R(2,2): Start 2, End 4. Comp 2.
    # R(3,2): Arrived 3. Queue at 4: R(3,2), S(4,2). Picked S.
    #     R(3,2) waits for S to finish. S finishes 6.
    #     R(3,2) starts 6, ends 8. Comp 8-3 = 5.
    #     Total Remote = 4 + 2 + 5 = 11. Avg = 3.666667.
    # 
    # THIS IS THE KEY DIFFERENCE!
    # In Sample 1 (3 techs), at T=4, when S arrives:
    # R(1,4) finishes. R(2,2) finishes (or finishes at 4). R(3,2) finishes (3+2=5).
    # At T=4, all 3 techs finish R(1,4), R(2,2), R(3,2) ?
    # No, R(3,2) started at 3, ends at 5.
    # With 3 techs:
    # T=1: R(1,4) starts.
    # T=2: R(2,2) starts.
    # T=3: R(3,2) starts.
    # At T=4:
    # T1 (R1): Ends 5.
    # T2 (R2): Ends 4.
    # T3 (R3): Ends 5.
    # So only T2 is free at T=4. S(4,2) starts on T2. Ends 6.
    # R(1,4) ends 5. S(5,1) arrives 5. Starts on T1 (freed). Ends 6.
    # R(3,2) ends 5. No new S at 5 (S(5,1) is taken). R(3,2) is done.
    # 
    # Sample 1 Remote:
    # R(1,4): Start 1, End 5. Comp 4.
    # R(2,2): Start 2, End 4. Comp 2.
    # R(3,2): Start 3, End 5. Comp 2.
    # Total 8. Avg 2.666. Matches.
    # 
    # Sample 2 Remote (Hypothesis confirmed):
    # R(1,4): Start 1, End 5. Comp 4.
    # R(2,2): Start 2, End 4. Comp 2.
    # R(3,2): Arrived 3. Waited (because at 4, S arrived and took the slot). Started 6. End 8. Comp 5.
    # Total 11. Avg 3.666. Matches.
    # 
    # So the algorithm is:
    # Maintain Queue of pending prescriptions (prioritizing S > R, then Drop Time, then Fill Time).
    # Maintain List of Finish Times.
    # Maintain List of Busy Techs.
    # 
    # 1. Current Time = 0.
    # 2. While there are unprocessed inputs or busy techs:
    #    a. Check inputs arriving at Current Time. Add to Queue. Sort Queue.
    #    b. Check Techs finishing at Current Time. Mark Free. Add results.
    #    c. Assign Free Techs to Queue items (prioritizing Queue order).
    #    d. Advance Time to next event (next input arrival or next finish).
    
    avg_in, avg_rem = await run_test(dut, test_data_2, 2)
    
    if abs(avg_in - 1.5) > 0.001 or abs(avg_rem - 3.666667) > 0.001:
        raise TestFailure(f"Case 2 failed. Got {avg_in:.6f} {avg_rem:.6f}")

@cocotb.test()
async def test_pharmacy_case3(dut):
    """Test Case 3: 5 scripts, 1 tech -> In: 3.0, Rem: 7.0"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Expected logic: 1 Tech.
    # T=1: R(1,4) starts. Ends 5.
    # T=2: R(2,2) arrives. Tech busy. Wait.
    # T=3: R(3,2) arrives. Wait.
    # T=4: S(4,2) arrives. Wait.
    # T=5: R(1,4) finishes. Queue: R(2,2), R(3,2), S(4,2). 
    #      Sort: S(4,2) first. S starts 5. Ends 7.
    # T=5: S(5,1) arrives. Wait.
    # T=7: S(4,2) finishes. Queue: S(5,1), R(2,2), R(3,2). 
    #      Sort: S(5,1) first. S starts 7. Ends 8.
    # T=8: S(5,1) finishes. Queue: R(2,2), R(3,2).
    #      Sort: R(2,2) (Drop 2) vs R(3,2) (Drop 3). R(2,2) first.
    #      R(2,2) starts 8. Ends 10.
    # T=10: R(2,2) finishes. Queue: R(3,2).
    #       R(3,2) starts 10. Ends 12.
    # 
    # In-store:
    # S(4,2): Start 5, End 7. Comp 2.
    # S(5,1): Start 7, End 8. Comp 2.
    # Total 4. Avg 2.0. 
    # 
    # Wait, Sample Output 3 says 3.0 for In-store.
    # Let's re-read Sample 3 output: "3.000000 7.000000"
    # 
    # Let's trace carefully.
    # 1 Tech.
    # Time 1: R(1,4) arrives. Starts immediately. Ends 5.
    # Time 2: R(2,2) arrives. Queued.
    # Time 3: R(3,2) arrives. Queued.
    # Time 4: S(4,2) arrives. Queued.
    # Time 5: S(5,1) arrives. Queued.
    # 
    # Time 5: R(1,4) finishes.
    # Queue at T=5: [S(4,2), S(5,1), R(2,2), R(3,2)].
    # Pick S(4,2). Starts 5. Ends 7.
    # 
    # Time 7: S(4,2) finishes.
    # Queue at T=7: [S(5,1), R(2,2), R(3,2)].
    # Pick S(5,1). Starts 7. Ends 8.
    # 
    # Time 8: S(5,1) finishes.
    # Queue at T=8: [R(2,2), R(3,2)].
    # Pick R(2,2). Starts 8. Ends 10.
    # 
    # Time 10: R(2,2) finishes.
    # Queue at T=10: [R(3,2)].
    # Pick R(3,2). Starts 10. Ends 12.
    # 
    # In-Store:
    # S(4,2): Drop 4, Finish 7. Comp = 3. (Waited 1s).
    # S(5,1): Drop 5, Finish 8. Comp = 3. (Waited 2s).
    # Sum = 6. Avg = 3.0. MATCHES.
    # 
    # Remote:
    # R(1,4): Drop 1, Finish 5. Comp = 4.
    # R(2,2): Drop 2, Finish 10. Comp = 8. (Waited 6s).
    # R(3,2): Drop 3, Finish 12. Comp = 9. (Waited 7s).
    # Sum = 21. Avg = 7.0. MATCHES.
    
    avg_in, avg_rem = await run_test(dut, test_data_1, 1)
    
    if abs(avg_in - 3.0) > 0.001 or abs(avg_rem - 7.0) > 0.001:
        raise TestFailure(f"Case 3 failed. Got {avg_in:.6f} {avg_rem:.6f}")
