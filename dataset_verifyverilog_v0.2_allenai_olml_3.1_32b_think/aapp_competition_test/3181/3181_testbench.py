import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure, TestSuccess

@cocotb.test()
async def test_construct_sequence(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N_in.value = 0
    dut.K_in.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    async def run_test(N, K, expected_result):
        dut._log.info(f"Testing N={N}, K={K}, expected={expected_result}")
        dut.start.value = 1
        dut.N_in.value = N
        dut.K_in.value = K
        await RisingEdge(dut.clk)
        dut.start.value = 0

        if expected_result == "-1":
            # Wait for error signal or done
            timeout = 0
            while not (dut.done.value or dut.error.value):
                await RisingEdge(dut.clk)
                timeout += 1
                if timeout > 50: break
            if not dut.error.value:
                raise TestFailure(f"Expected error for N={N}, K={K}")
        else:
            # Collect sequence
            sequence = []
            done = False
            # Wait for valid or done
            timeout = 0
            while not done:
                if dut.valid.value:
                    sequence.append(int(dut.sequence_out.value))
                if dut.done.value and not dut.valid.value: # Done might pulse with last data or separate
                    # Check if we are done
                    if len(sequence) == N: done = True
                    else: done = True # Or wait for output? Assuming done goes high after N outputs
                await RisingEdge(dut.clk)
                timeout += 1
                if timeout > 100:
                    raise TestFailure(f"Timeout for N={N}, K={K}")
            
            # Verify sequence properties
            # 1. Permutation of 1..N
            if sorted(sequence) != list(range(1, N + 1)):
                raise TestFailure(f"Not a permutation: {sequence}")
            
            # 2. Calculate LIS and LDS
            def get_lis(arr):
                if not arr: return 0
                dp = [1]*len(arr)
                for i in range(len(arr)):
                    for j in range(i):
                        if arr[j] < arr[i]:
                            dp[i] = max(dp[i], dp[j] + 1)
                return max(dp)
            
            def get_lds(arr):
                if not arr: return 0
                dp = [1]*len(arr)
                for i in range(len(arr)):
                    for j in range(i):
                        if arr[j] > arr[i]:
                            dp[i] = max(dp[i], dp[j] + 1)
                return max(dp)
            
            lis = get_lis(sequence)
            lds = get_lds(sequence)
            max_mono = max(lis, lds)
            \
            if max_mono != K:
                raise TestFailure(f"Sequence {sequence} has max monotone subsequence {max_mono} (LIS={lis}, LDS={lds}), expected {K}")

    # Test Case 1: N=4, K=3. N <= K^2 (9). Expect solution.
    # M=K=3 blocks. Sizes: 4/3=1 rem 1. Sizes: [2,1,1].
    # Values: Block 1 (1-2): 2,1. Block 2 (3): 3. Block 3 (4): 4. Seq: 2 1 3 4.
    # LIS? 1,3,4 -> 3. LDS? 2,1 -> 2. Max=3. OK.
    await run_test(4, 3, "valid")

    # Test Case 2: N=5, K=1. N > 1, K=1 -> Impossible.
    await run_test(5, 1, "-1")

    # Test Case 3: N=5, K=5. N <= K^2 (25). Expect solution.
    # M=5 blocks. Sizes: 5/5=1 rem 0. Sizes [1,1,1,1,1].
    # Seq: 1 2 3 4 5. LIS=5. OK.
    await run_test(5, 5, "valid")

    # Test Case 4: N=8, K=3. N=8, K^2=9. Should work.
    # M=3 blocks. Sizes: 8/3=2 rem 2. Sizes [3,3,2].
    # Max size 3 <= K (3). OK.
    # Seq: (1-3 -> 3,2,1), (4-6 -> 6,5,4), (7-8 -> 8,7).
    # 3,2,1,6,5,4,8,7. LIS? 1,4,7 -> 3. LDS? 3,2,1 -> 3. Max=3. OK.
    await run_test(8, 3, "valid")

    # Test Case 5: N=10, K=3. K^2=9, N=10 > 9. Impossible.
    await run_test(10, 3, "-1")

    # Test Case 6: N=1, K=1. Valid.
    await run_test(1, 1, "valid")