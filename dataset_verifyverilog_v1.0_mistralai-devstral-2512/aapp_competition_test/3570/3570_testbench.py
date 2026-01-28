import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Helpers (MANDATORY) ---
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# --- String Hashing (Hardware friendly approximation) ---
def string_to_hash(s):
    # Simple 20-bit hash for Verilog compatibility
    h = 0
    for i, c in enumerate(s[:16]):
        h = (h + (ord(c) << ((i % 5) * 4))) & 0xFFFFF
    return h

# --- Setup ---
DATA_WIDTH = 20
CLK_NS = 10
MAX_CYCLES = 2048

class OpType:
    EVENT = 0
    DREAM = 1
    SCENARIO = 2

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dream_parser(dut):
    # Setup Clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Helper to run an operation
    async def run_op(type_code, a1, a2=0, a3=0, a4=0):
        if not is_seq:
            await Timer(100, units='ns')
            return
            
        dut.op_type.value = type_code
        dut.arg1.value = clamp_to_width(a1, 20)
        dut.arg2.value = clamp_to_width(a2, 20)
        dut.arg3.value = clamp_to_width(a3, 20)
        dut.arg4.value = clamp_to_width(a4, 20)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while True:
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout in run_op {type_code}")
        
        status = int(dut.status.value) if has_signal(dut, 'status') else 0
        return status, safe_int(dut.dream_depth.value)

    # --- Test Case 1: From Sample ---
    cocotb.log.info("Running Sample Test Case 1")
    
    # 1. E business_as_usual
    hash_bus = string_to_hash("business_as_usual")
    stat, _ = await run_op(OpType.EVENT, hash_bus)
    if stat != 0: raise TestFailure("Expected Yes for E business_as_usual")

    # 2. E bobby_dies
    hash_bobby = string_to_hash("bobby_dies")
    stat, _ = await run_op(OpType.EVENT, hash_bobby)
    if stat != 0: raise TestFailure("Expected Yes for E bobby_dies")

    # 3. S 1 bobby_died (Note: typo in sample? input says bobby_died, but event was bobby_dies)
    # Let's assume strict matching. "bobby_died" != "bobby_dies".
    # So it's an unknown event. Should be Plot Error or Just A Dream.
    # Sample output says "Plot Error" for the first one.
    # Let's try strictly.
    hash_bobby_died = string_to_hash("bobby_died")
    # Packed args for S: k=1. arg2 needs bits. 
    # Bit 0-19: Event ID. 
    # Bit 20: Negation (0).
    # So arg2 = (0 << 20) | hash_bobby_died. But arg2 is 20 bits wide.
    # We need to pack into 20-bit args. 
    # Let's assume k=1 fits in arg2 alone (event in lower bits, neg in bit 19).
    # Simulating the packed format: 1 bit neg (MSB of 20-bit chunk), 19 bits hash?
    # Let's assume 20 bits total per entry: 1 neg, 19 hash.
    # For S 1 bobby_died: k=1. 
    # arg1 = 1 (k)
    # arg2 = (0 << 19) | hash_bobby_died (assuming hash fits 19 bits)
    # To be safe, let's assume hash is 16 bits for packing simplicity or use a wider bus.
    # The spec says arg2 is 20-bit. 
    # Let's simplify hashing to 16-bit for packing 2 entries per word if needed, but here k=1.
    # Let's use 16-bit hash.
    def hash16(s):
        h = 0
        for i, c in enumerate(s[:16]):
            h = (h ^ (ord(c) << (i%2)*8)) & 0xFFFF
        return h
    
    h_bus16 = hash16("business_as_usual")
    h_bob16 = hash16("bobby_dies")
    h_bob_died16 = hash16("bobby_died")

    # Rerun with 16-bit hashes
    stat, _ = await run_op(OpType.EVENT, h_bus16)
    stat, _ = await run_op(OpType.EVENT, h_bob16)

    # S 1 bobby_died -> Unknown event -> Plot Error
    # k=1. Neg=0. Hash=h_bob_died16.
    # Pack into arg2: (0 << 16) | h_bob_died16
    pack = (0 << 16) | h_bob_died16
    stat, depth = await run_op(OpType.SCENARIO, 1, pack)
    if stat != 2: # 2 is Plot Error
        raise TestFailure(f"Expected Plot Error for S 1 bobby_died, got {stat}")

    # 4. E stuff_happens
    h_sh = hash16("stuff_happens")
    await run_op(OpType.EVENT, h_sh)

    # 5. E jr_does_bad_things
    h_jr = hash16("jr_does_bad_things")
    await run_op(OpType.EVENT, h_jr)

    # 6. S 2 !bobby_dies business_as_usual
    # !bobby_dies (negated, should NOT be in RAM) -> it IS in RAM -> Conflict on !bobby_dies
    # So should be Plot Error or Just A Dream.
    # Sample output: "3 Just A Dream"
    # Wait, let's trace. 
    # Current RAM: business_as_usual, bobby_dies, stuff_happens, jr_does_bad_things.
    # Scenario requires: !bobby_dies (Fail, it exists), business_as_usual (Pass).
    # It fails. 
    # Is it consistent with D 3? D 3 removes last 3: jr_does_bad_things, stuff_happens, bobby_dies.
    # Remaining: business_as_usual.
    # New state: business_as_usual.
    # Check scenario: !bobby_dies (Pass, not in RAM), business_as_usual (Pass).
    # So D 3 works. Output "3 Just A Dream".
    
    # Pack args: k=2. 
    # Entry 1: !bobby_dies (neg=1, hash=bob). 
    # Entry 2: business_as_usual (neg=0, hash=bus).
    # Packed 20-bit args. Let's use 10 bits hash, 1 bit neg -> 2 entries per 20-bit word.
    # This is getting complex for HDL interface. 
    # Let's assume the Verilog module unpacks `arg2` to `arg3`.
    # For test, we just send values.
    
    # Re-defining hash for 10 bits to pack 2 per word
    def hash10(s):
        h = 0
        for c in s:
            h = (h + ord(c)) & 0x3FF
        return h
    
    h_bus10 = hash10("business_as_usual")
    h_bob10 = hash10("bobby_dies")
    h_sh10 = hash10("stuff_happens")
    h_jr10 = hash10("jr_does_bad_things")

    # Re-populate with 10-bit hashes
    await run_op(OpType.EVENT, h_bus10)
    await run_op(OpType.EVENT, h_bob10)
    await run_op(OpType.EVENT, h_sh10)
    await run_op(OpType.EVENT, h_jr10)

    # S 2 !bobby_dies business_as_usual
    # k=2. 
    # Word 1 (arg2): 
    #   Entry 1 (!bobby_dies): Neg=1 (0x400), Hash=h_bob10 -> Val = 0x400 | h_bob10
    #   Entry 2 (business_as_usual): Neg=0 (0x0), Hash=h_bus10 -> Val = h_bus10
    # Packed: (Val1 << 11) | Val2. (11 bits per entry: 1 neg + 10 hash).
    # arg2 = (( (0x400 | h_bob10) << 11 ) | h_bus10) & 0xFFFFF
    val1 = (0x400 | h_bob10)
    val2 = h_bus10
    arg2_val = ((val1 << 11) | val2) & 0xFFFFF
    
    stat, depth = await run_op(OpType.SCENARIO, 2, arg2_val)
    if stat != 1: # 1 is Just A Dream
        raise TestFailure(f"Expected Just A Dream (depth 3), got status {stat}")
    if depth != 3:
        raise TestFailure(f"Expected depth 3, got {depth}")

    # 7. E it_goes_on_and_on
    h_ito = hash10("it_goes_on_and_on")
    await run_op(OpType.EVENT, h_ito)

    # 8. D 4
    await run_op(OpType.DREAM, 4)
    # Current stack: business_as_usual, bobby_dies (wait, D 4 popped 4, we had 4 events + 1 new = 5 total)
    # Events: bus, bob, sh, jr, ito.
    # D 4 removes ito, jr, sh, bob.
    # Remaining: bus.

    # 9. S 1 !bobby_dies
    # Current RAM: bus. !bobby_dies is valid (bob not in RAM).
    # Should be Yes.
    val1 = (0x400 | h_bob10) # !bobby_dies
    arg2_val = val1
    stat, _ = await run_op(OpType.SCENARIO, 1, arg2_val)
    if stat != 0: # Yes
        raise TestFailure(f"Expected Yes, got {stat}")

    # 10. S 2 !bobby_dies it_goes_on_and_on
    # Current RAM: bus. 
    # Needs: !bobby_dies (Pass), it_goes_on_and_on (Fail, not in RAM).
    # So Plot Error.
    # Check dream fallback: D 1 removes bus. RAM empty.
    # !bobby_dies (Pass), it_goes_on_and_on (Fail, not in RAM).
    # D 2 removes bus + (empty). RAM empty.
    # ... No dream works because we need it_goes_on_and_on to be true, but it was popped.
    # Wait, D r removes events. 
    # We need it_goes_on_and_on to happen. 
    # Current state: bus. it_goes_on_and_on was popped by D 4.
    # To bring it back, we need to roll back the D 4? No, input is linear.
    # We can only roll back *current* events.
    # Current events: bus. 
    # We can't un-dream D 4.
    # So it_goes_on_and_on is permanently gone (unless it was before D 4).
    # Wait, the list is chronological. D 4 removed 4 events *before* it.
    # The event it_goes_on_and_on was *after* the events that were just removed?
    # No. `E it_goes_on_and_on` was line 7. `D 4` was line 8.
    # `D 4` removed the 4 events before it. 
    # Events before D 4: bus, bob, sh, jr, ito.
    # `ito` is the last one. D 4 removes ito, jr, sh, bob.
    # Remaining: bus.
    # The scenario checks *current* reality. 
    # It asks: is it possible `ito` happened?
    # Only if we dreamed the D 4 line.
    # But the problem asks: "provided a D r line had occurred just before the scenario".
    # This means rolling back *current* history.
    # Current history: [bus].
    # D 1 removes bus. History: []
    # `ito` was not in history (it was removed by D 4).
    # Wait, the problem description says "these events are now considered to not have happened".
    # This implies the history stack is mutable.
    # If D 4 removed events, they are gone. 
    # To have `ito` again, we would need to have NOT executed D 4, or have it before D 4.
    # But the input is linear. 
    # Let's re-read: "Scenario would be consistent... provided a D r line had occurred just before the scenario."
    # This implies we are looking for `r` such that if we roll back `r` steps from *now*, the scenario holds.
    # Current events: [business_as_usual].
    # Scenario: !bobby_dies (OK), it_goes_on_and_on (NOT OK).
    # Can we make `ito` true? `ito` was removed by D 4. It is not in the current stack. 
    # You cannot bring back events removed by a previous D operation using a *new* D operation.
    # You can only remove events that are currently present.
    # So `ito` is impossible. Result should be Plot Error.
    
    val1 = (0x400 | h_bob10) # !bobby_dies
    val2 = h_ito             # it_goes_on_and_on
    arg2_val = ((val1 << 11) | val2) & 0xFFFFF
    stat, _ = await run_op(OpType.SCENARIO, 2, arg2_val)
    if stat != 2: # Plot Error
        raise TestFailure(f"Expected Plot Error, got {stat}")

    cocotb.log.info("All sample tests passed")

    # --- Test Case 2: From Sample ---
    # This test involves repeated D operations.
    cocotb.log.info("Running Sample Test Case 2")
    
    # Reset for fresh start
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # S 1 !something -> Yes (empty state, !something is valid)
    h_something = hash10("something")
    val1 = (0x400 | h_something)
    stat, _ = await run_op(OpType.SCENARIO, 1, val1)
    if stat != 0: raise TestFailure("TC2: Expected Yes")

    # E one, two, three, four, five
    for s in ["one", "two", "three", "four", "five"]:
        await run_op(OpType.EVENT, hash10(s))

    # S 3 three !four one
    # Current: one, two, three, four, five (stack grows up)
    # Wait, stack pointer usually increments. 
    # Events: one, two, three, four, five.
    # Stack: [one, two, three, four, five]
    # Scenario: three (OK), !four (FAIL, four is present), one (OK).
    # So Plot Error.
    # Check dream fallback: 
    # D 1 removes five. Stack: [one, two, three, four]. 
    # three (OK), !four (FAIL).
    # D 2 removes five, four. Stack: [one, two, three].
    # three (OK), !four (OK), one (OK). -> Yes!
    # Sample output: "2 Just A Dream"
    
    h_one = hash10("one")
    h_two = hash10("two")
    h_three = hash10("three")
    h_four = hash10("four")
    h_five = hash10("five")
    
    # k=3. 
    # Entry 1: three (neg=0, hash=h_three)
    # Entry 2: !four (neg=1, hash=h_four)
    # Entry 3: one (neg=0, hash=h_one)
    # Packed into arg2, arg3 (3 entries * 11 bits = 33 bits -> need 2 words)
    # arg2: bits 0-10 (entry 3), 11-21 (entry 2)
    # arg3: bits 0-10 (entry 1)
    
    val3 = h_one
    val2 = (0x400 | h_four)
    val1 = h_three
    
    arg2_val = ((val2 << 11) | val3) & 0xFFFFF
    arg3_val = val1 & 0xFFFFF
    
    stat, depth = await run_op(OpType.SCENARIO, 3, arg2_val, arg3_val)
    if stat != 1: raise TestFailure(f"TC2: Expected Just A Dream, got {stat}")
    if depth != 2: raise TestFailure(f"TC2: Expected depth 2, got {depth}")

    # D 1
    await run_op(OpType.DREAM, 1)
    
    # S 3 three !four one
    # Current stack: [one, two, three, four] (five removed by previous D 1 + D 2 check logic?)
    # Wait, D operations are real. 
    # We ran D 1 (hypothetically for scenario) but did we commit it? 
    # No, scenario check is hypothetical.
    # But line 6 is `D 1`. This is a real dream.
    # State before D 1: [one, two, three, four, five]
    # State after D 1: [one, two, three, four]
    
    # Check scenario again: three (!four one)
    # Stack: [one, two, three, four]
    # three (OK), !four (FAIL), one (OK).
    # Dream fallback:
    # D 1 removes four. Stack: [one, two, three].
    # three (OK), !four (OK), one (OK). -> Yes!
    # Sample output: "1 Just A Dream"
    
    stat, depth = await run_op(OpType.SCENARIO, 3, arg2_val, arg3_val)
    if stat != 1: raise TestFailure(f"TC2: Expected Just A Dream, got {stat}")
    if depth != 1: raise TestFailure(f"TC2: Expected depth 1, got {depth}")

    # D 1
    await run_op(OpType.DREAM, 1)
    
    # S 3 three !four one
    # Current stack: [one, two, three]
    # three (OK), !four (OK), one (OK). -> Yes!
    # Sample output: "Yes"
    
    stat, _ = await run_op(OpType.SCENARIO, 3, arg2_val, arg3_val)
    if stat != 0: raise TestFailure(f"TC2: Expected Yes, got {stat}")

    cocotb.log.info("All tests passed successfully")