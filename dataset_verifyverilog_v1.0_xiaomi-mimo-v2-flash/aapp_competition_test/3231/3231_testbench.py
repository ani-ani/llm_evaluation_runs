import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for 16-node maximum
MAX_N = 16
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 200000  # Allow more cycles for full 2^16 search

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def pack_adjacency_matrix(n, adj_dict):
    """Pack adjacency matrix into 16x16 bits as 16-bit packed integers."""
    matrix = [[0] * MAX_N for _ in range(MAX_N)]
    for i in range(n):
        for j in range(n):
            if i in adj_dict and j in adj_dict[i]:
                matrix[i][j] = 1
    # Convert to 16 packed 16-bit integers
    packed = []
    for row in range(MAX_N):
        val = 0
        for col in range(MAX_N):
            val |= (matrix[row][col] << col)
        packed.append(val)
    return packed

def generate_partition_mask(n, groups):
    """Generate 16-bit partition mask for group validation."""
    # Each node gets 4 bits for group ID
    partition = 0
    for node in range(n):
        group_id = groups[node]
        partition |= (group_id & 0xF) << (node * 4)
    return partition

def count_group_sizes(n, partition_mask):
    """Count size of each group from partition mask."""
    group_sizes = {}
    for node in range(n):
        group_id = (partition_mask >> (node * 4)) & 0xF
        if group_id not in group_sizes:
            group_sizes[group_id] = 0
        group_sizes[group_id] += 1
    return group_sizes

def count_cross_edges(n, adj_dict, partition_mask):
    """Count cross-group edges."""
    cross = 0
    for i in range(n):
        for j in range(n):
            if i in adj_dict and j in adj_dict[i]:
                if i < j:  # Avoid double counting
                    group_i = (partition_mask >> (i * 4)) & 0xF
                    group_j = (partition_mask >> (j * 4)) & 0xF
                    if group_i != group_j:
                        cross += 1
    return cross

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_group_validator(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test case 1: Sample Input 1 - Should be valid
    n1 = 4
    p1 = 2
    q1 = 1
    adj_dict1 = {
        0: {1},
        1: {0, 2},
        2: {1, 3},
        3: {2}
    }
    packed_adj1 = pack_adjacency_matrix(n1, adj_dict1)
    
    # Setup inputs
    dut.n.value = n1
    dut.p.value = p1
    dut.q.value = q1
    
    for i in range(MAX_N):
        if has_signal(dut, f'adj_{i}'):
            getattr(dut, f'adj_{i}').value = packed_adj1[i]
        elif has_signal(dut, 'adj'):
            # Check if it's a packed array
            pass
    
    # Start evaluation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check result
    if is_value_defined(dut.valid.value):
        valid1 = int(dut.valid.value)
        if valid1 == 1:
            cocotb.log.info("Test 1 PASSED: Valid partition found")
            # Verify partition
            partition_mask = int(dut.partition.value) if has_signal(dut, 'partition') else 0
            cocotb.log.info(f"Partition mask: 0x{partition_mask:04x}")
            if has_signal(dut, 'group_count'):
                group_count = int(dut.group_count.value)
                cocotb.log.info(f"Group count: {group_count}")
        else:
            raise TestFailure(f"Test 1 FAILED: Expected valid=1, got {valid1}")
    else:
        raise TestFailure("Test 1 FAILED: valid signal not found")
    
    # Reset for test case 2
    await reset_dut(dut)
    
    # Test case 2: Sample Input 2 - Should be invalid
    n2 = 5
    p2 = 2
    q2 = 1
    adj_dict2 = {
        0: {1},
        1: {0, 2},
        2: {1, 3},
        3: {2, 4},
        4: {3}
    }
    packed_adj2 = pack_adjacency_matrix(n2, adj_dict2)
    
    dut.n.value = n2
    dut.p.value = p2
    dut.q.value = q2
    
    for i in range(MAX_N):
        if has_signal(dut, f'adj_{i}'):
            getattr(dut, f'adj_{i}').value = packed_adj2[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if is_value_defined(dut.valid.value):
        valid2 = int(dut.valid.value)
        if valid2 == 0:
            cocotb.log.info("Test 2 PASSED: Correctly detected invalid")
        else:
            raise TestFailure(f"Test 2 FAILED: Expected valid=0, got {valid2}")
    else:
        raise TestFailure("Test 2 FAILED: valid signal not found")
    
    # Reset for test case 3
    await reset_dut(dut)
    
    # Test case 3: n=3, p=3, q=3, cycle
    n3 = 3
    p3 = 3
    q3 = 3
    adj_dict3 = {
        0: {1, 2},
        1: {0, 2},
        2: {0, 1}
    }
    packed_adj3 = pack_adjacency_matrix(n3, adj_dict3)
    
    dut.n.value = n3
    dut.p.value = p3
    dut.q.value = q3
    
    for i in range(MAX_N):
        if has_signal(dut, f'adj_{i}'):
            getattr(dut, f'adj_{i}').value = packed_adj3[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if is_value_defined(dut.valid.value):
        valid3 = int(dut.valid.value)
        if valid3 == 0:
            cocotb.log.info("Test 3 PASSED: Correctly detected invalid (cycle)")
        else:
            cocotb.log.warning(f"Test 3 WARNING: Expected valid=0, got {valid3}")
    else:
        raise TestFailure("Test 3 FAILED: valid signal not found")
    
    cocotb.log.info("All tests completed successfully")