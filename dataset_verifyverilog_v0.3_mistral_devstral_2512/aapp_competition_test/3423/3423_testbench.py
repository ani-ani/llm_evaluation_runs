import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
MAX_PACKAGES = 8
NAME_WIDTH = 128
CLK_PERIOD = 10

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def name_to_bits(name):
    """Convert string to 128-bit integer (left-aligned)."""
    if len(name) > 16:
        name = name[:16]
    bits = 0
    for i, char in enumerate(name):
        bits |= ord(char) << (8 * (15 - i))
    return bits

def bits_to_name(bits):
    """Convert 128-bit integer back to string."""
    chars = []
    for i in range(16):
        char_bits = (bits >> (8 * (15 - i))) & 0xFF
        if char_bits:
            chars.append(chr(char_bits))
    return ''.join(chars)

def build_deps(packages, dependencies):
    """Build dependency bit vectors."""
    name_to_idx = {name: i for i, name in enumerate(packages)}
    deps = [0] * MAX_PACKAGES
    for i, dep_list in enumerate(dependencies):
        for dep in dep_list:
            if dep in name_to_idx:
                deps[i] |= (1 << name_to_idx[dep])
    return deps

def topological_sort(packages, dependencies):
    """Python reference implementation."""
    from collections import defaultdict
    from heapq import heappush, heappop
    
    n = len(packages)
    name_to_idx = {name: i for i, name in enumerate(packages)}
    
    indegree = [0] * n
    graph = defaultdict(list)
    
    for i, deps in enumerate(dependencies):
        for dep in deps:
            if dep in name_to_idx:
                j = name_to_idx[dep]
                graph[j].append(i)
                indegree[i] += 1
    
    heap = []
    for i in range(n):
        if indegree[i] == 0:
            heappush(heap, (packages[i], i))
    
    order = []
    while heap:
        name, idx = heappop(heap)
        order.append(name)
        for neighbor in graph[idx]:
            indegree[neighbor] -= 1
            if indegree[neighbor] == 0:
                heappush(heap, (packages[neighbor], neighbor))
    
    if len(order) == n:
        return order, False
    return None, True

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure("Timeout waiting for done")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_package_installer(dut):
    """Test package installer with multiple cases."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (['libattr', 'vim-common', 'vim-X11'], [[], ['libattr'], ['vim-common']], ['libattr', 'vim-common', 'vim-X11'], 'Simple chain'),
        (['atk', 'pango', 'glib2', 'grep'], [[], ['atk'], ['pango'], ['atk']], ['atk', 'pango', 'glib2', 'grep'], 'Lexicographic'),
        (['emacs', 'xorg-x11', 'lisp'], [['xorg-x11', 'lisp'], ['emacs'], ['emacs']], None, 'Cycle detection'),
    ]
    
    for packages, dependencies, expected, desc in test_cases:
        cocotb.log.info(f"Test: {desc}")
        n = len(packages)
        
        # Get reference
        ref_order, has_error = topological_sort(packages, dependencies)
        deps_matrix = build_deps(packages, dependencies)
        
        # Feed inputs
        for i in range(n):
            name_bits = name_to_bits(packages[i])
            if has_signal(dut, f'pkg_{i}'):
                getattr(dut, f'pkg_{i}').value = name_bits
            elif has_signal(dut, 'pkg_0'):
                getattr(dut, f'pkg_{i}').value = name_bits
        
        for i in range(n):
            if has_signal(dut, f'deps_{i}'):
                getattr(dut, f'deps_{i}').value = deps_matrix[i]
        
        if has_signal(dut, 'num_packages'):
            dut.num_packages.value = n
        
        # Start
        await RisingEdge(dut.clk)
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait
        if has_signal(dut, 'done'):
            await wait_for_done(dut)
            
            if has_signal(dut, 'error') and is_value_defined(dut.error.value):
                if int(dut.error.value) == 1:
                    if has_error:
                        cocotb.log.info(f"  PASS: Cycle detected")
                        continue
                    else:
                        raise TestFailure(f"Unexpected error")
            
            result_order = []
            for i in range(n):
                if has_signal(dut, f'result_{i}'):
                    val = getattr(dut, f'result_{i}').value
                    if is_value_defined(val) and int(val) != 0:
                        result_order.append(bits_to_name(int(val)))
            
            if expected is not None:
                if result_order == expected:
                    cocotb.log.info(f"  PASS: {result_order}")
                else:
                    raise TestFailure(f"Expected {expected}, got {result_order}")
            else:
                raise TestFailure(f"Expected error but got result")
        else:
            await Timer(100, units='ns')
            result_order = []
            for i in range(n):
                if has_signal(dut, f'result_{i}'):
                    val = getattr(dut, f'result_{i}').value
                    if is_value_defined(val) and int(val) != 0:
                        result_order.append(bits_to_name(int(val)))
            
            if expected is not None:
                if result_order == expected:
                    cocotb.log.info(f"  PASS: {result_order}")
                else:
                    raise TestFailure(f"Expected {expected}, got {result_order}")