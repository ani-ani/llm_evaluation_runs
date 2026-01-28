import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def calc_fnv1a_hash(bytes_list):
    hash_val = 0x811c9dc5  # FNV-1a 32-bit offset basis
    for b in bytes_list:
        hash_val ^= b
        hash_val = (hash_val * 0x01000193) & 0xFFFFFFFF
    return hash_val

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_sublists(dut, sublists):
    # sublists: list of 4 lists, each 4 ints (bytes)
    # Assumes flattened interface 'sublists_flat' (16 bits) or separate ports
    if has_signal(dut, 'sublists_flat'):
        flat = 0
        for i, sub in enumerate(sublists):
            for j, b in enumerate(sub):
                pos = i * 16 + j * 8
                flat |= (b & 0xFF) << pos
        dut.sublists_flat.value = flat
    else:
        # Assume ports like sublist_0_0, sublist_0_1...
        for i in range(4):
            for j in range(4):
                port_name = f'sublist_{i}_{j}'
                if has_signal(dut, port_name):
                    val = sublists[i][j]
                    getattr(dut, port_name).value = clamp_to_width(val, 8)

def count_unique(sublists):
    hashes = [calc_fnv1a_hash(s) for s in sublists]
    seen = {}
    for h in hashes:
        seen[h] = seen.get(h, 0) + 1
    # Return as list of (hash, count) in order of first appearance
    result = []
    added = set()
    for h in hashes:
        if h not in added:
            result.append((h, seen[h]))
            added.add(h)
    return result

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_unique_sublists(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational
        await Timer(10, units='ns')

    # Test Cases
    # Map integers to ASCII for verification. Max 4 chars.
    # Case 1: [97, 99, 0, 0], [101, 103, 0, 0], [97, 99, 0, 0], [109, 111, 113, 0]
    # Expected: Hash1 (count 2), Hash2 (count 1), Hash3 (count 1)
    
    input_data = [
        ([97, 99, 0, 0], [101, 103, 0, 0], [97, 99, 0, 0], [109, 111, 113, 0]),
        ([65, 66, 67, 68], [65, 66, 67, 68], [65, 66, 67, 68], [69, 70, 71, 72]), # All same, expect 2 unique
        ([1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]), # All distinct
    ]

    for sub0, sub1, sub2, sub3 in input_data:
        sublists = [sub0, sub1, sub2, sub3]
        
        # Write inputs
        await write_sublists(dut, sublists)
        
        if has_signal(dut, 'clk'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            found_done = False
            for _ in range(200):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found_done = True
                    break
            
            if not found_done:
                raise TestFailure("Timeout waiting for 'done'")
        else:
            await Timer(100, units='ns')

        # Verify Results
        expected = count_unique(sublists)
        
        collected = []
        for i in range(4):
            valid_name = f'result_valid_{i}'
            hash_name = f'result_hash_{i}'
            count_name = f'result_count_{i}'
            
            if has_signal(dut, valid_name):
                valid = int(getattr(dut, valid_name).value)
                if valid:
                    h = int(getattr(dut, hash_name).value)
                    c = int(getattr(dut, count_name).value)
                    collected.append((h, c))
            elif has_signal(dut, 'result_valid'):
                valid_vec = int(dut.result_valid.value)
                if (valid_vec >> i) & 1:
                    h = int(dut.result_hash.value) # Assuming vector or array
                    c = int(dut.result_count.value)
                    # This logic is tricky for vectors, assuming 4 outputs valid for now
                    # Let's stick to the specific per-index ports for clarity
                    pass
        
        # Check counts and hashes match (order matters as per spec: first appearance)
        if len(collected) != len(expected):
            raise TestFailure(f"Result count mismatch. Got {len(collected)}, Expected {len(expected)}")
        
        for idx, (exp_h, exp_c) in enumerate(expected):
            got_h, got_c = collected[idx]
            if got_h != exp_h or got_c != exp_c:
                raise TestFailure(f"Slot {idx}: Got ({got_h}, {got_c}), Exp ({exp_h}, {exp_c})")
                
        cocotb.log.info(f"Test Passed for input: {sublists}")
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
