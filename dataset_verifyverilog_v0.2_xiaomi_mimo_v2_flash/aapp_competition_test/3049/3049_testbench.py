import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_substitution_cipher_matcher(dut):
    """Test substitution cipher matcher with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.encrypted_msg.value = 0
    dut.fragment.value = 0
    dut.msg_len.value = 0
    dut.frag_len.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: secretmessage / boot -> essa
    # 's'->'e', 'e'->'s', 'c'->'s', 't'->'a' (but 'c' and 't' both need to map to 's' and 'a')
    # Actually: 'boot' maps to 'essa': b->e, o->s, o->s, t->a (o maps consistently)
    print("
Test 1: encrypted='secretmessage', fragment='boot'")
    dut.encrypted_msg.value = int.from_bytes(b'secretmessage'.ljust(16), 'big')
    dut.fragment.value = int.from_bytes(b'boot'.ljust(8), 'big')
    dut.msg_len.value = 13
    dut.frag_len.value = 4
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 256 cycles + overhead)
    timeout = 300
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Test 1 timed out")
    
    result_pos = int(dut.result_pos.value)
    match_count = int(dut.match_count.value)
    result_str_raw = int(dut.result_string.value).to_bytes(16, 'big').rstrip(b'\x00').decode('ascii', errors='ignore')
    
    print(f"  Result: pos={result_pos}, count={match_count}, str='{result_str_raw}'")
    assert result_pos == 6, f"Expected pos=6, got {result_pos}"
    assert match_count == 1, f"Expected count=1, got {match_count}"
    # The result string should be the substring from position 6
    # secretmessage[6:10] = "essa" (positions 6,7,8,9: e,s,s,a)
    # But wait, we need to check which substring matches
    # 'boot' maps to 'essa': b->e, o->s, o->s, t->a
    # So we look for substring where there exists a consistent mapping
    # In 'secretmessage', at position 0: 'secr' - could map? s->b, e->o, c->o, r->t
    # e and c both map to o, invalid. 
    # Position 6: 'essa' - e->b, s->o, s->o, a->t - this works!
    # So result should be "essa"
    
    # Test 2: treetreetreetree / wood -> 3 positions
    print("
Test 2: encrypted='treetreetreetree', fragment='wood'")
    dut.encrypted_msg.value = int.from_bytes(b'treetreetreetree', 'big')
    dut.fragment.value = int.from_bytes(b'wood'.ljust(8), 'big')
    dut.msg_len.value = 16
    dut.frag_len.value = 4
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 300
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Test 2 timed out")
    
    result_pos = int(dut.result_pos.value)
    match_count = int(dut.match_count.value)
    print(f"  Result: pos={result_pos}, count={match_count}")
    # For 'wood' -> w->t, o->r, o->e, d->e  (t, r, e, e) is 'tree'
    # w->t, o->r, d->e. But then o->e as well, which conflicts with o->r
    # Wait, let's recheck: wood->tree requires w->t, o->r, o->e (conflict)
    # Actually, 'wood' has 2 o's, which must map to same letter.
    # 'tree' has t, r, e, e. So we need o->e and d->e, but then o and d both map to e, invalid
    # We need substring like 'ttee' where t and e are repeated
    # Actually, let's check position 0: 'tree' - t->w, r->o, e->o, e->d (r and e both map to o? No)
    # For wood->tree: w->t, o->r, o->e (can't, o maps to 2 different things)
    # For wood->'ttee' doesn't exist, but there is 'treetreetreetree'
    # We need substring where 2nd and 4th chars are same (for o's)
    # 'tree' has e at pos 2 and 3, but o's must map to same
    # Let's check 'ttee' (t,t,e,e): wood w->t, o->t, o->e, d->e (o maps to t and e, invalid)
    # Actually we need: wood w->x, o->y, o->y, d->z. So substring must have same pattern.
    # Check position 0: tree: t,r,e,e. Need y=y for o's, so positions 1 and 2 must be same? No, o is at pos 1 and 2 in wood.
    # Wait: wood is w-o-o-d. So positions 1 and 2 are both 'o'.
    # Substring must have same letter at positions 1 and 2 for o's to map correctly.
    # 't r e e' -> positions 2 and 3 are same (e,e). So wood w->t, o->r? Wait, w-o-o-d
    # Actually we need substring where position 1 == position 2.
    # In 'treetreetreetree': positions 2&3 of first tree: e==e. So t- r- e- e.
    # wood: w(0) o(1) o(2) d(3). Map w->t, o->r, d->e? But o(1) and o(2) both map to r, but substring has r at pos1, e at pos2.
    # NO. o(1) must map to sub[1], o(2) must map to sub[2]. So sub[1] must equal sub[2].
    # Check 't r e e' -> sub[1]='r', sub[2]='e'. Different. NO.
    # Check 't e e s' (position 0-3 of treetreetreetree is tree, pos 4-7 is tree, etc)
    # Actually we need to find substring with sub[1]==sub[2].
    # In 'treetreetreetree': 't r e e' has sub[1]='r', sub[2]='e'. NO.
    # But 't r e e' has sub[2]='e', sub[3]='e'. Wait. We need indices 1 and 2 of the fragment window.
    # Fragment 'wood' length 4. Substring indices 0,1,2,3. We need sub[1]==sub[2].
    # In 'treetreetreetree': check windows:
    # 0-3: tree -> sub[1]='r', sub[2]='e' -> NO
    # 1-4: reet -> sub[1]='e', sub[2]='e' -> YES!
    # 2-5: eetr -> sub[1]='e', sub[2]='e' -> YES!
    # 3-6: ettr -> sub[1]='t', sub[2]='t' -> YES!
    # 4-7: tree -> NO
    # 5-8: reet -> YES
    # 6-9: eetr -> YES
    # 7-10: ettr -> YES
    # 8-11: tree -> NO
    # 9-12: reet -> YES
    # 10-13: eetr -> YES
    # 11-14: ettr -> YES
    # 12-15: tree -> NO
    # Wait, let's count carefully. Window of 4 in 16 chars: 13 positions.
    # Positions with sub[1]==sub[2]: 1,2,3,5,6,7,9,10,11. That's 9 positions.
    # Let me re-read sample output: "3".
    # Oh. Maybe I misunderstood. Let's re-read problem.
    # "different letters in the original message become different letters in the encrypted one"
    # So mapping must be bijective.
    # wood -> sub. wood has w,o,o,d. distinct chars: w,o,d.
    # sub must have exactly 3 distinct chars, where the repeated 'o' maps to a repeated char in sub.
    # Check 'tree': distinct chars t,r,e (3 distinct). 'o' maps to 'r'? But o is at pos 1 and 2. sub[1]=r, sub[2]=e. Different. Invalid.
    # wood maps to sub only if sub[1]==sub[2].
    # 'treetreetreetree'. Let's find windows of 4 where sub[1]==sub[2]:
    # Window start 0: sub[1]=r, sub[2]=e. NO.
    # Window start 1: sub[1]=e, sub[2]=e. YES. Substring "reet"
    # Window start 2: sub[1]=e, sub[2]=t. NO.
    # Wait. treetreetreetree. Indices: 0123 4567 8901 2345 (t r e e t r e e t r e e t r e e)
    # Window 1-4: r e e t. indices of window 0,1,2,3 -> r(0), e(1), e(2), t(3). Sub[1]=e, Sub[2]=e. YES.
    # Window 2-5: e e t r. Sub[1]=e, Sub[2]=t. NO.
    # Window 3-6: e t r e. Sub[1]=t, Sub[2]=r. NO.
    # Window 4-7: t r e e. Sub[1]=r, Sub[2]=e. NO.
    # Window 5-8: r e e t. YES.
    # Window 6-9: e e t r. NO.
    # Window 7-10: e t r e. NO.
    # Window 8-11: t r e e. NO.
    # Window 9-12: r e e t. YES.
    # Window 10-13: e e t r. NO.
    # Window 11-14: e t r e. NO.
    # Window 12-15: t r e e. NO.
    # So positions 1, 5, 9. That's 3 positions. Correct.
    
    assert match_count == 3, f"Expected count=3, got {match_count}"
    assert result_pos == 0, f"Expected pos=0 (multiple matches), got {result_pos}"
    
    # Test 3: oranges / apples -> 0
    print("
Test 3: encrypted='oranges', fragment='apples'")
    dut.encrypted_msg.value = int.from_bytes(b'oranges'.ljust(16), 'big')
    dut.fragment.value = int.from_bytes(b'apples'.ljust(8), 'big')
    dut.msg_len.value = 7
    dut.frag_len.value = 6
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 300
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Test 3 timed out")
    
    result_pos = int(dut.result_pos.value)
    match_count = int(dut.match_count.value)
    print(f"  Result: pos={result_pos}, count={match_count}")
    assert match_count == 0, f"Expected count=0, got {match_count}"
    assert result_pos == 0, f"Expected pos=0, got {result_pos}"
    
    # Test 4: archipelago / submarine -> 2
    print("
Test 4: encrypted='archipelago', fragment='submarine'")
    dut.encrypted_msg.value = int.from_bytes(b'archipelago'.ljust(16), 'big')
    dut.fragment.value = int.from_bytes(b'submarine'.ljust(8), 'big')
    dut.msg_len.value = 11
    dut.frag_len.value = 9
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 300
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Test 4 timed out")
    
    result_pos = int(dut.result_pos.value)
    match_count = int(dut.match_count.value)
    print(f"  Result: pos={result_pos}, count={match_count}")
    assert match_count == 2, f"Expected count=2, got {match_count}"
    assert result_pos == 0, f"Expected pos=0, got {result_pos}"
    
    print("
All tests passed!")
