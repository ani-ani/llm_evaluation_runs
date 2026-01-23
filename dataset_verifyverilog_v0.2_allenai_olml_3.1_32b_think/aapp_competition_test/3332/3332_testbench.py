import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_priority_subset(dut):
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.s_i.value = 0
    dut.d_i.value = 0
    dut.p_i.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1 from problem statement (scaled down)
    # Original: 4 streams. We fit into 8 streams.
    # Stream 1: s=1, d=3, p=6 -> e=4
    # Stream 2: s=2, d=5, p=8 -> e=7
    # Stream 3: s=3, d=3, p=5 -> e=6
    # Stream 4: s=5, d=3, p=6 -> e=8
    # We use these 4, and fill rest with dummy zeros (p=0).
    # Optimal solution: S1(0-3), S4(5-8) -> total 6+6=12? No.
    # Let's analyze:
    # S1 (1,3,6) -> [1,4)
    # S2 (2,5,8) -> [2,7)
    # S3 (3,3,5) -> [3,6)
    # S4 (5,3,6) -> [5,8)
    # Stack constraint: S2 (2,7) contains S3 (3,6) -> Valid (Nested).
    # S1 (1,4) and S2 (2,7) cross -> Invalid.
    # S1 (1,4) and S4 (5,8) separate -> Valid.
    # S2 (2,7) and S4 (5,8) overlap but not nested (5<7, 8>7) -> Invalid.
    # S3 (3,6) and S4 (5,8) overlap -> Invalid (S4 starts inside S3, ends outside).
    # Possible sets:
    # {S1, S4}: 6+6=12 (Valid)
    # {S2, ?} -> S2 includes S3, but S2 and S1 cross, S2 and S4 cross.
    # {S2, S3}: 8+5=13 (Valid, Nested).
    # {S3, S4}: Invalid.
    # Max is 13.

    inputs = [
        (1, 3, 6),
        (2, 5, 8),
        (3, 3, 5),
        (5, 3, 6),
        (0, 0, 0),
        (0, 0, 0),
        (0, 0, 0),
        (0, 0, 0)
    ]

    dut._log.info("Starting Test Case 1")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Feed inputs
    for s, d, p in inputs:
        dut.valid_in.value = 1
        dut.s_i.value = s
        dut.d_i.value = d
        dut.p_i.value = p
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Module did not finish in time")
        
    # Check result
    if int(dut.result.value) != 13:
        raise TestFailure(f"Expected 13, got {int(dut.result.value)}")
    dut._log.info("Test Case 1 Passed")

    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2 (scaled down version of 6 streams case)
    # Original:
    # 1: 5 4 10 -> [5,9)
    # 2: 3 4 6 -> [3,7)
    # 3: 1 8 100 -> [1,9)
    # 4: 3 2 3 -> [3,5)
    # 5: 4 2 4 -> [4,6)
    # 6: 3 2 2 -> [3,5)
    # Optimal: {S3 (100), S4 (3), S5 (4)}? 
    # S3 [1,9) contains S4 [3,5) and S5 [4,6). 
    # S4 and S5 overlap (4<5, 6>5) -> Invalid.
    # S4 [3,5) and S6 [3,5) overlap exactly -> Invalid.
    # Let's try {S3 (100), S1 (10)}? S3 [1,9), S1 [5,9). 
    # S1 starts inside S3, ends at same time? [5,9) inside [1,9)? Yes, strict.
    # Total: 100+10 = 110.
    # Let's try {S2 (6), S3 (100)}? [3,7) and [1,9) -> Cross/Over -> Invalid.
    # Let's try {S2 (6), S4 (3), S5 (4), S6 (2)}?
    # S2 [3,7) contains S4 [3,5) -> Invalid (start at same time).
    # S2 [3,7) contains S6 [3,5) -> Invalid.
    # S2 [3,7) contains S5 [4,6) -> Valid.
    # S4 [3,5) and S5 [4,6) -> Cross -> Invalid.
    # Max seems to be 110? Wait, sample output is 115.
    # Re-read: S3 [1,9) contains S1 [5,9) -> 100+10=110.
    # S3 [1,9) contains S2 [3,7)? [3,7) inside [1,9) -> Yes. 100+6=106.
    # S3 [1,9) contains S4 [3,5)? Yes. 100+3=103.
    # Wait, maybe {S3 (100), S1 (10), S5 (4)}? 
    # S3 [1,9), S1 [5,9), S5 [4,6). 
    # S5 inside S3 (valid). S1 inside S3 (valid). S5 and S1 overlap? [4,6) and [5,9) -> Cross -> Invalid.
    # What gives 115?
    # Maybe S2 (6), S4 (3), S5 (4), S6 (2) = 15? No.
    # Maybe S3 (100), and something else? 
    # Let's recheck problem logic. Stack LIFO.
    # If S3 starts (push 3). S1 starts (push 1). S3 ends (pop 1? No, top is 1). S1 ends (pop 1). S3 ends (pop 3). Valid.
    # If S3 starts (push 3). S2 starts (push 2). S2 ends (pop 2). S3 ends (pop 3). Valid.
    # S3 [1,9), S2 [3,7), S1 [5,9). 
    # Order: S3 push 3. S2 push 2. S1 push 1.
    # S2 ends at 7? But S1 ends at 9. Top is 1. We must pop 1 first. 
    # But S2 ends at 7 < 9. We must generate report for S2 at 7.
    # This violates the rule: "report must be produced immediately after its termination".
    # So S2 cannot be inside S3 if S1 is also inside S3, because S2 ends before S1.
    # This means: S2 and S1 cannot both be inside S3. One must be nested inside the other.
    # So {S3 (100), S2 (6), S4 (3)}? 
    # S3 [1,9), S2 [3,7), S4 [3,5). 
    # S4 inside S2 inside S3. 
    # Push 3, push 2, push 4. 
    # Pop 4 (5), Pop 2 (7), Pop 3 (9). Valid. Total: 100+6+3=109.
    # {S3 (100), S2 (6), S5 (4)}? 
    # S5 [4,6). S2 [3,7). S5 inside S2. 
    # Push 3, 2, 5. Pop 5 (6), Pop 2 (7), Pop 3 (9). Valid. Total: 100+6+4=110.
    # {S3 (100), S1 (10), S5 (4)}? 
    # S5 [4,6), S1 [5,9). S5 inside S1? No, S5 starts before S1. 
    # S1 inside S5? No, S1 ends after S5.
    # So S5 and S1 Cross -> Invalid.
    # {S3 (100), S4 (3), S5 (4), S6 (2)}? 
    # S4 [3,5), S5 [4,6), S6 [3,5).
    # S4 and S6 overlap -> Invalid.
    # S5 inside S4? No. S4 inside S5? No.
    # {S2 (6), S4 (3), S5 (4), S6 (2)}?
    # S2 [3,7). S4 [3,5) -> Strict? No, start same. Invalid.
    # Let's check 115 again. 
    # 100 (S3) + 6 (S2) + 4 (S5) + 2 (S6)? 
    # Can S6 be inside S5? S6 [3,5), S5 [4,6). No.
    # Can S4 be inside S5? S4 [3,5), S5 [4,6). No.
    # Wait, maybe S3 (100) + S1 (10) + ... 
    # If we don't take S3? 
    # S2 (6), S1 (10)? [3,7) and [5,9) -> Cross -> Invalid.
    # S2 (6), S5 (4). [3,7) contains [4,6). Valid. Total 10.
    # S1 (10), S5 (4)? [5,9) and [4,6) -> Cross -> Invalid.
    # S2 (6), S4 (3), S5 (4), S6 (2). 
    # S2 [3,7). Inside S2: S4 [3,5), S5 [4,6), S6 [3,5).
    # S4 and S6 overlap -> Only one of S4/S6 allowed inside S2.
    # S4 and S5 overlap -> Only one of S4/S5 allowed.
    # S5 and S6 overlap -> Only one of S5/S6 allowed.
    # Best inside S2: S2 (6) + S5 (4) = 10. (S4 and S6 overlap with S5). 
    # Wait, S4 and S5 are [3,5) and [4,6). They cross. 
    # S5 and S6 are [4,6) and [3,5). They cross.
    # So max inside S2 is S2 (6) + max( S4, S5, S6 ) = 6+4=10 (using S5).
    # Or S2 (6) + S4 (3) + ? S4 is [3,5). S6 is [3,5). S5 crosses both.
    # So S2 (6) + S4 (3) = 9.
    # So S2 (6) + S6 (2) = 8.
    # So {S2, S5} = 10.
    # What about {S3 (100), S1 (10), S4 (3)}? 
    # S3 [1,9), S1 [5,9), S4 [3,5).
    # S4 inside S3. S1 inside S3.
    # S4 and S1 do not cross (S4 [3,5), S1 [5,9)). 
    # But can they be nested in stack?
    # Push 3, 4, 1. 
    # S1 ends at 9. Top is 1. Pop 1. 
    # S4 ended at 5. But top was 1. We missed S4 report.
    # So S4 must end AFTER S1 starts?
    # S4 ends 5, S1 starts 5. 
    # If S1 starts at 5, S4 ends at 5.
    # If S1 starts at 5, and we push S1, then S4 is popped.
    # But S4 ended at 5. 
    # Condition: "report immediately after termination".
    # If S4 ends at 5, report at 5.
    # If S1 starts at 5, it must be pushed at 5.
    # Stack: S3 pushed. S4 pushed. S4 ends. Pop S4. Push S1. ...
    # This implies S1 must start strictly after S4 ends. Or S1 must be pushed before S4 starts?
    # No, push on start.
    # So S4 [3,5) and S1 [5,9) are allowed IF S4 is pushed then popped BEFORE S1 is pushed.
    # But they share the time point 5.
    # Usually in these problems, [s, s+d) means ends at s+d.
    # [5, 9) starts at 5. 
    # So S4 finishes at 5. S1 starts at 5.
    # Push S4, Pop S4 (at time 5), Push S1.
    # This works! S4 and S1 are disjoint.
    # So {S3 (100), S4 (3), S1 (10)} is Valid.
    # Total: 100 + 3 + 10 = 113.
    # Is there 2 more? 
    # S5 [4,6). S5 and S1 cross (4<5, 6<9). 
    # S5 and S4 cross (4<5, 6>5). 
    # S6 [3,5). S6 and S1 disjoint. S6 and S4 overlap.
    # So we can have {S3 (100), S4 (3), S1 (10)} = 113.
    # What about {S3 (100), S6 (2), S1 (10)} = 112.
    # What about {S3 (100), S4 (3), S5 (4)}? 
    # S3, S4, S5. S4 [3,5), S5 [4,6). Cross -> Invalid.
    # So 113 is the best with S3.
    # What if we don't take S3?
    # {S2 (6), S4 (3), S5 (4), S6 (2)}? 
    # S2 [3,7). Inside S2: S4 [3,5) -> strict? Start same -> No.
    # S2 [3,7) and S6 [3,5) -> Start same -> No.
    # S2 [3,7) and S5 [4,6) -> Valid (nested). Total 10.
    # {S1 (10), S5 (4)} -> Cross -> No.
    # {S2 (6), S1 (10)} -> Cross -> No.
    # {S2 (6), S4 (3)} -> No.
    # So 113 seems max.
    # But sample output is 115.
    # Let's re-read input 2 exactly.
    # 6
    # 5 4 10  -> [5, 9)
    # 3 4 6   -> [3, 7)
    # 1 8 100 -> [1, 9)
    # 3 2 3   -> [3, 5)
    # 4 2 4   -> [4, 6)
    # 3 2 2   -> [3, 5)
    # Wait, S4 [3,5), S6 [3,5). Same start and end.
    # Can we take both S4 and S6? They overlap. [3,5) and [3,5). 
    # LIFO: Push S4, Push S6. Pop S6 (5), Pop S4 (5).
    # If they end at same time, we must pop S6 then S4.
    # Is that allowed? "report immediately after termination".
    # If they both terminate at 5, we can pop S6 then S4.
    # Are they considered overlapping? 
    # "report immediately after its termination; otherwise, it will be useless".
    # If S4 ends at 5, report at 5.
    # If S6 ends at 5, report at 5.
    # We can't report both at exactly time 5 (instantaneous).
    # So they conflict.
    # But wait. Let's check 115.
    # 100 (S3) + 10 (S1) + 3 (S4) + 2 (S6) = 115.
    # S4 and S6 are [3,5). 
    # Can they both be selected? 
    # If S3 is outer. S4 and S6 are inside S3.
    # S4 [3,5), S6 [3,5). 
    # S1 [5,9) is also inside S3.
    # Order: Push S3. Push S4. Push S6. Push S1.
    # S4 ends 5. S6 ends 5. S1 starts 5.
    # At time 5, S4 and S6 are done. S1 starts.
    # If we push S1 at 5, we can't pop S4 or S6.
    # So we must pop S6 and S4 before pushing S1.
    # But they end at 5.
    # Maybe the interval is [s, s+d] closed?
    # Problem says [s, s+d) right-open.
    # So S4 ends strictly before 5? No, 3+2=5.
    # Maybe S4 and S6 can be nested? 
    # S4 [3,5), S6 [3,5) -> Not nested.
    # S4 [3,5) and S1 [5,9) -> Disjoint.
    # S6 [3,5) and S1 [5,9) -> Disjoint.
    # S4 and S6 -> Overlap.
    # Is it possible S4 and S6 are NOT in the same stack branch? 
    # No, single stack.
    # Let's re-evaluate 115.
    # 100 + 10 + 3 + 2 = 115.
    # This implies S3, S1, S4, S6 are all selected.
    # If S4 and S6 overlap, they must be nested.
    # But they are same interval.
    # Maybe they are not the same interval? 
    # S4: 3 2 3 -> [3,5)
    # S6: 3 2 2 -> [3,5)
    # Identical intervals.
    # In interval graphs, non-overlapping independent set is for non-crossing.
    # S4 and S6 cross? 
    # s4=3, e4=5. s6=3, e6=5.
    # Is [3,5) nested in [3,5)? No.
    # Are they separate? No.
    # Maybe the problem allows them if they are "pushed" in a specific order.
    # Push S4, Push S6. Pop S6 (5), Pop S4 (5).
    # If report is instantaneous, we can do Pop S6 then Pop S4.
    # If time is discrete, 5, 5.
    # If time is continuous, instant.
    # Usually, overlapping start times are allowed to be pushed in any order.
    # But they must finish in reverse order.
    # If S4 and S6 finish at same time, they must finish in reverse order.
    # Is that possible? Yes.
    # So S4 and S6 can be selected if they have same end time?
    # If they have same end time, one must be pushed after the other.
    # Then popped in reverse.
    # So S4 [3,5) and S6 [3,5) can be selected if pushed as (S4, S6) then popped (S6, S4).
    # This implies they are nested? 
    # S6 is inside S4? No, they occupy same time.
    # But strictly, [3,5) is not strictly inside [3,5).
    # However, if they are identical, we can schedule them one after another.
    # Wait, if they run concurrently, they can't.
    # But the system pushes them.
    # Does the stream duration imply processing time?
    # "Each processor performs some real time processing... immediately after its termination, produces a report".
    # This implies the stream is active for duration d.
    # So two streams with same interval are active simultaneously.
    # If S4 and S6 are active [3,5), and we have 1 OGU.
    # The OGU can only process one report at a time.
    # They both need the OGU at time 5.
    # We can't process both at time 5.
    # So S4 and S6 cannot be selected together.
    # So 115 must come from different combination.
    # 115 = 100 + 6 + 4 + 5? No 5.
    # 115 = 100 + 10 + 5? No.
    # 115 = 100 + 6 + 3 + 4 + 2? 115 = 100+6+3+4+2 = 115.
    # S3(100), S2(6), S4(3), S5(4), S6(2).
    # S3 [1,9). Inside: S2 [3,7), S4 [3,5), S5 [4,6), S6 [3,5).
    # S4 and S6 cross -> No.
    # S4 and S5 cross -> No.
    # S5 and S6 cross -> No.
    # S2 and S4 cross (start same) -> No.
    # S2 and S5 nested? [4,6) in [3,7). Yes.
    # S2 and S6 cross (start same) -> No.
    # So we can have S3, S2, S5 -> 100+6+4=110.
    # What about S3, S1, S5? -> Cross -> No.
    # What about S3, S1, S4? -> Disjoint? [5,9) and [3,5). Yes.
    # S3, S1, S4 -> 100+10+3=113.
    # What about S3, S1, S6? -> 100+10+2=112.
    # What about S3, S2, S4, S5, S6?
    # Inside S2 (S2 is inside S3). 
    # S2 [3,7). Inside S2: S5 [4,6). (S4/S6 cross S2 start).
    # So S3, S2, S5 = 110.
    # What if we don't take S3?
    # S1 [5,9). S2 [3,7). S2 and S1 cross -> No.
    # S1 [5,9). S5 [4,6). Cross -> No.
    # S2 [3,7). S5 [4,6). Nested -> 10.
    # So 115 seems impossible with my strict interpretation.
    # Let's look at 115 again. 
    # Maybe S4 [3,5) and S6 [3,5) are considered "nested" if pushed in order?
    # If they are identical, can we treat them as nested? 
    # If s4==s6 and e4==e6, they are identical.
    # If we push S4, then S6. S6 is "inside" S4? No.
    # But maybe the condition is:
    # E[i] <= S[j] or E[j] <= S[i] or (S[i] < S[j] and E[j] < E[i]) or (S[j] < S[i] and E[i] < E[j]).
    # For identical: S[i]==S[j] and E[i]==E[j].
    # None of these hold.
    # So identical intervals should conflict.
    # Is there another number?
    # 115 = 100 + 15.
    # 15 = 6+3+4+2 = 15.
    # We established 6+4=10 is best in S2.
    # 6+3+2=11.
    # 6+3+4=13.
    # 6+3+4+2=15.
    # But we can't take 3,4,2 together.
    # Wait, maybe S4 [3,5) and S6 [3,5) don't conflict if they are 
    # pushed in sequence?
    # But they run for duration 2.
    # If they both start at 3, they both need processing at 5.
    # So they conflict.
    # Unless the OGU is instantaneous and we can do two reports at 5.
    # "report immediately after its termination; otherwise, it will be useless. An OGU creates a report extremely fast, so you can assume that an OGU produces this report instantly."
    # "extremely fast" -> maybe "infinitely fast"? 
    # If instantaneous, then at time 5, we can pop S6, report, pop S4, report.
    # If they are instantaneous, then identical intervals might be allowed.
    # If we assume instantaneous reporting, then S4 and S6 can be selected if pushed in reverse order.
    # This means they are effectively "nested" or just a sequence.
    # If we allow identical intervals, then the condition for valid set is:
    # For any two selected intervals I, J:
    # They must not cross.
    # Crossing means s1 < s2 < e1 < e2.
    # If s1 == s2 or e1 == e2, it's not strictly crossing.
    # Is it nested? No.
    # But if we can reorder the popping, maybe it's fine.
    # If s1 == s2, e1 == e2. 
    # Push I, Push J. Pop J, Pop I. Valid.
    # If s1 == s2, e1 < e2. 
    # Push I, Push J. J ends later. Pop J? No, I ends first.
    # So s1 == s2 implies e1 == e2 is required.
    # So in this case, S4 and S6 are compatible ONLY if they are identical.
    # If so, 115 = 100 + 10 + 3 + 2 is valid.
    # Let's assume identical intervals are allowed (push order choice).

    # Test Case 2 inputs:
    inputs2 = [
        (5, 4, 10),
        (3, 4, 6),
        (1, 8, 100),
        (3, 2, 3),
        (4, 2, 4),
        (3, 2, 2),
        (0, 0, 0),
        (0, 0, 0)
    ]

    dut._log.info("Starting Test Case 2")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for s, d, p in inputs2:
        dut.valid_in.value = 1
        dut.s_i.value = s
        dut.d_i.value = d
        dut.p_i.value = p
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Module did not finish in time")
        
    if int(dut.result.value) != 115:
        raise TestFailure(f"Expected 115, got {int(dut.result.value)}")
    dut._log.info("Test Case 2 Passed")
