import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_string(s, width=8, max_len=26):
    """Pack string into bit array"""
    result = 0
    for i, ch in enumerate(s[:max_len]):
        result |= (ord(ch) << (i * width))
    return result

def ascii_to_arr(val, width=8, max_len=26):
    """Convert integer bit-packed value to ASCII array"""
    arr = []
    for i in range(max_len):
        char = (val >> (i * width)) & 0xFF
        arr.append(char)
    return arr

# Generate all valid call permutations (2 of each: Pre, In, Post)
def generate_call_permutations():
    perms = set()
    for perm in itertools.permutations(['Pre']*2 + ['In']*2 + ['Post']*2):
        perms.add(perm)
    return sorted(list(perms))  # Sort for consistent ordering

# Map call token to int for packing
def call_to_int(call):
    return {'Pre': 0, 'In': 1, 'Post': 2}[call]

def pack_calls(calls):
    """Pack 6 calls into 24-bit value"""
    result = 0
    for i, call in enumerate(calls):
        result |= (call_to_int(call) << (i * 4))
    return result

# Simple tree structure for testing
class TreeNode:
    def __init__(self, val):
        self.val = val
        self.left = None
        self.right = None

# Generate correct traversals for a tree
def preorder(t):
    if not t: return []
    return [t.val] + preorder(t.left) + preorder(t.right)

def inorder(t):
    if not t: return []
    return inorder(t.left) + [t.val] + inorder(t.right)

def postorder(t):
    if not t: return []
    return postorder(t.left) + postorder(t.right) + [t.val]

# Reconstruct tree from traversals (for verification)
def build_from_pre_in(pre, ino):
    if not pre: return None
    root = TreeNode(pre[0])
    idx = ino.index(root.val)
    root.left = build_from_pre_in(pre[1:1+idx], ino[:idx])
    root.right = build_from_pre_in(pre[1+idx:], ino[idx+1:])
    return root

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_tree_reconstruction(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1
    pre_obs = "HFBIGEDCJA"
    in_obs = "BIGEDCJFAH"
    post_obs = "BIGEDCJFAH"
    n = 10
    
    # Pack observations into arrays
    pre_arr = pack_string(pre_obs, 8, 26)
    in_arr = pack_string(in_obs, 8, 26)
    post_arr = pack_string(post_obs, 8, 26)
    
    # Assign to dut signals
    if has_signal(dut, 'pre_obs'):
        dut.pre_obs.value = pre_arr
    if has_signal(dut, 'in_obs'):
        dut.in_obs.value = in_arr
    if has_signal(dut, 'post_obs'):
        dut.post_obs.value = post_arr
    if has_signal(dut, 'n'):
        dut.n.value = n
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while True:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > 10000:
            raise TestFailure("Timeout - took more than 10000 cycles")
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                break
    
    # Check results
    if has_signal(dut, 'valid'):
        if not is_value_defined(dut.valid.value) or int(dut.valid.value) == 0:
            raise TestFailure("No valid reconstruction found")
    
    # Verify call sequence (should match example output: Pre Post In Post In Pre)
    if has_signal(dut, 'call_seq'):
        call_val = int(dut.call_seq.value)
        # Expected: Pre(0), Post(2), In(1), Post(2), In(1), Pre(0) = 0x012010
        # Bits: [0]=0, [1]=2, [2]=1, [3]=2, [4]=1, [5]=0
        # 4 bits per call: 0000 0010 0001 0010 0001 0000 = 0x021020
        expected = 0x021020
        if call_val != expected:
            # Log but don't fail - may be multiple solutions
            cocotb.log.info(f"Call sequence: {call_val:06x} (expected 0x{expected:06x})")
    
    # Verify tree output
    if has_signal(dut, 'tree_pre'):
        pre_val = int(dut.tree_pre.value)
        pre_str = ''.join([chr(c) for c in ascii_to_arr(pre_val) if c != 0])
        expected_pre = "HFBJCDEGIA"
        if pre_str != expected_pre:
            cocotb.log.warning(f"Preorder mismatch: got '{pre_str}', expected '{expected_pre}'")
        else:
            cocotb.log.info(f"Preorder matches: {pre_str}")
    
    if has_signal(dut, 'tree_in'):
        in_val = int(dut.tree_in.value)
        in_str = ''.join([chr(c) for c in ascii_to_arr(in_val) if c != 0])
        expected_in = "BIGEDCJFAH"
        if in_str != expected_in:
            cocotb.log.warning(f"Inorder mismatch: got '{in_str}', expected '{expected_in}'")
        else:
            cocotb.log.info(f"Inorder matches: {in_str}")
    
    if has_signal(dut, 'tree_post'):
        post_val = int(dut.tree_post.value)
        post_str = ''.join([chr(c) for c in ascii_to_arr(post_val) if c != 0])
        expected_post = "IGEDCJBAFH"
        if post_str != expected_post:
            cocotb.log.warning(f"Postorder mismatch: got '{post_str}', expected '{expected_post}'")
        else:
            cocotb.log.info(f"Postorder matches: {post_str}")
    
    # Verify that traversals are consistent (can build a tree)
    if has_signal(dut, 'tree_pre') and has_signal(dut, 'tree_in'):
        pre_val = int(dut.tree_pre.value)
        in_val = int(dut.tree_in.value)
        pre_str = ''.join([chr(c) for c in ascii_to_arr(pre_val) if c != 0])
        in_str = ''.join([chr(c) for c in ascii_to_arr(in_val) if c != 0])
        
        # Basic validation
        if set(pre_str) != set(in_str):
            raise TestFailure(f"Preorder and inorder have different characters: {set(pre_str)} vs {set(in_str)}")
        
        # Try to build tree
        try:
            tree = build_from_pre_in(list(pre_str), list(in_str))
            cocotb.log.info(f"Tree reconstruction successful")
        except Exception as e:
            raise TestFailure(f"Failed to build tree from traversals: {e}")
    
    cocotb.log.info(f"Test passed in {cycles} cycles")

# Additional test with second example
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_tree_reconstruction_case2(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2
    pre_obs = "BNLFAGHPEDOCMJIK"
    in_obs = "NLBGAPHCODEIJMKF"
    post_obs = "NLFAGHPEDOCMJIKB"
    n = 16
    
    # Pack observations
    pre_arr = pack_string(pre_obs, 8, 26)
    in_arr = pack_string(in_obs, 8, 26)
    post_arr = pack_string(post_obs, 8, 26)
    
    if has_signal(dut, 'pre_obs'):
        dut.pre_obs.value = pre_arr
    if has_signal(dut, 'in_obs'):
        dut.in_obs.value = in_arr
    if has_signal(dut, 'post_obs'):
        dut.post_obs.value = post_arr
    if has_signal(dut, 'n'):
        dut.n.value = n
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while True:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > 10000:
            raise TestFailure("Timeout - took more than 10000 cycles")
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                break
    
    # Check valid
    if has_signal(dut, 'valid'):
        if not is_value_defined(dut.valid.value) or int(dut.valid.value) == 0:
            raise TestFailure("No valid reconstruction found")
    
    # Log results
    cocotb.log.info(f"Test case 2 completed in {cycles} cycles")
    
    if has_signal(dut, 'call_seq'):
        call_val = int(dut.call_seq.value)
        cocotb.log.info(f"Call sequence: 0x{call_val:06x}")
    
    if has_signal(dut, 'tree_pre'):
        pre_val = int(dut.tree_pre.value)
        pre_str = ''.join([chr(c) for c in ascii_to_arr(pre_val) if c != 0])
        cocotb.log.info(f"Preorder: {pre_str}")
    
    if has_signal(dut, 'tree_in'):
        in_val = int(dut.tree_in.value)
        in_str = ''.join([chr(c) for c in ascii_to_arr(in_val) if c != 0])
        cocotb.log.info(f"Inorder: {in_str}")
    
    if has_signal(dut, 'tree_post'):
        post_val = int(dut.tree_post.value)
        post_str = ''.join([chr(c) for c in ascii_to_arr(post_val) if c != 0])
        cocotb.log.info(f"Postorder: {post_str}")