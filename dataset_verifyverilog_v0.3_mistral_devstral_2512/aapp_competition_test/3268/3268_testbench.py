import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
MAX_NODES = 8
MAX_LABEL_BITS = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_array(values, element_bits=8):
    result = 0
    for i, val in enumerate(values):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def run_test_case(dut, test_data):
    """Run a single test case on the DUT."""
    # Reset
    await reset_dut(dut)
    
    # Write inputs
    for i in range(MAX_NODES):
        # Parent array
        dut.parent[i].value = test_data['parents'][i]
        # Node type
        dut.node_type[i].value = test_data['types'][i]
        # Label - convert char to ASCII
        label_char = test_data['labels'][i]
        dut.label[i].value = ord(label_char) if label_char != '\0' else 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read results
    valid = safe_int(dut.valid.value)
    conflict_count = safe_int(dut.conflict_count.value)
    first_conflict = safe_int(dut.first_conflict_node.value)
    
    return valid, conflict_count, first_conflict

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_berry_assigner(dut):
    """Main test function for bird berry assigner."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test cases: each is a dict with parents, types, labels, expected_valid, description
    # Type encoding: 0:big branch, 1:small branch, 2:giant bird, 3:tiny bird, 4:berry
    # Labels: single char, '\0' for no label
    test_cases = [
        {
            'description': "Example 1 - 13 nodes scaled to 8: conflict after tiny->giant",
            'parents': [0, 1, 2, 2, 2, 5, 5, 5],  # Only first 8 nodes
            'types': [0, 0, 4, 4, 1, 2, 3, 4],    # 0:B, 1:S, 2:G, 3:T, 4:E
            'labels': ['\0', '\0', 'a', 'b', '\0', 'a', 'a', 'a'],
            'expected_valid': 0,  # Should detect conflict
            'expected_conflicts': 1,  # Both birds at 5 and 6 have label 'a', area becomes same
        },
        {
            'description': "Example 2 - 6 nodes scaled: tiny bird area change causes berry misassignment",
            'parents': [0, 1, 1, 2, 5],  # Only first 5 nodes used
            'types': [0, 0, 3, 4, 1],    # Node 2 is tiny bird, node 5 is tiny bird
            'labels': ['\0', '\0', 'a', 'a', 'a'],
            'expected_valid': 0,  # Should detect issue
            'expected_conflicts': 0,  # No area conflict but berry assignment invalid
        },
        {
            'description': "Simple valid case: one bird, one berry",
            'parents': [0, 1, 1],
            'types': [0, 2, 4],  # Big branch, giant bird, berry
            'labels': ['\0', 'x', 'x'],
            'expected_valid': 1,
            'expected_conflicts': 0,
        },
        {
            'description': "Two birds same label, different areas: valid",
            'parents': [0, 1, 1, 2, 3],
            'types': [0, 0, 2, 2, 4],  # Two big branches, two giant birds, berry
            'labels': ['\0', '\0', 'a', 'a', 'a'],
            'expected_valid': 1,
            'expected_conflicts': 0,
        },
        {
            'description': "Conflict: two tiny birds same label become giant with same area",
            'parents': [0, 1, 1, 2, 2],
            'types': [0, 1, 3, 3, 4],  # Small branch with two tiny birds
            'labels': ['\0', '\0', 'b', 'b', 'b'],
            'expected_valid': 0,
            'expected_conflicts': 1,
        },
        {
            'description': "No birds, only berries: invalid case",
            'parents': [0, 1, 1],
            'types': [0, 1, 4],
            'labels': ['\0', '\0', 'a'],
            'expected_valid': 0,
            'expected_conflicts': 0,
        },
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"\n=== Test {i+1}: {tc['description']} ===")
        
        try:
            valid, conflicts, first = await run_test_case(dut, tc)
            
            # Validate results
            if valid != tc['expected_valid']:
                raise TestFailure(
                    f"Valid mismatch: expected {tc['expected_valid']}, got {valid}"
                )
            
            if conflicts != tc['expected_conflicts']:
                raise TestFailure(
                    f"Conflict count mismatch: expected {tc['expected_conflicts']}, got {conflicts}"
                )
            
            cocotb.log.info(f"  PASS: valid={valid}, conflicts={conflicts}, first_conflict={first}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"RESULTS: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_label_packing(dut):
    """Verify that label array can be written correctly."""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test writing different labels
    test_labels = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']
    
    for i in range(MAX_NODES):
        dut.parent[i].value = 0
        dut.node_type[i].value = 0
        dut.label[i].value = ord(test_labels[i])
    
    # Verify readback
    await Timer(100, units='ns')
    
    for i in range(MAX_NODES):
        read_val = int(dut.label[i].value)
        expected = ord(test_labels[i])
        if read_val != expected:
            raise TestFailure(f"Label mismatch at index {i}: expected {expected}, got {read_val}")
    
    cocotb.log.info("Label packing test passed")
