module comb_sort_8x8 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [63:0] data_in,
    output logic [63:0] data_out,
    output logic        done
);

    // Internal storage for 8 elements (each 8-bit)
    logic [7:0] arr[0:7];

    // State machine encoding
    typedef enum logic [2:0] {
        IDLE          = 3'd0,
        LOAD          = 3'd1,
        COMPARE_GAP   = 3'd2,
        SWAP_IF_NEEDED= 3'd3,
        NEXT_PAIR     = 3'd4,
        UPDATE_GAP    = 3'd5,
        CHECK_SWAPPED = 3'd6,
        DONE_STATE    = 3'd7
    } state_t;

    state_t state, next_state;

    // Gap sequence index and values
    // Sequence for N=8: 6,4,3,2,1
    logic [2:0] gap;         // current gap
    logic [2:0] gap_idx;     // index into gap sequence (0..4)

    // Pair index for current gap pass
    logic [2:0] pair_idx;    // i for pair (i, i+gap)

    // Swap tracking for each gap pass
    logic swapped;           // indicates if any swap occurred in current gap pass
    logic swap_any;          // combinational OR of swap decisions for current cycle

    // Parallel compare/swap support
    // We will perform up to 4 comparisons in parallel (for gap=1 case).
    // We'll generate swap decisions and then sequentially update arr inside SWAP_IF_NEEDED.

    // Wires for compare decisions per lane
    logic [3:0] cmp_do_swap;

    // Local indices for up to 4 parallel pairs
    logic [2:0] idx_a[0:3];
    logic [2:0] idx_b[0:3];
    logic [3:0] valid_pair;

    // Gap sequence lookup (combinational)
    function automatic logic [2:0] gap_lut(input logic [2:0] idx);
        case (idx)
            3'd0: gap_lut = 3'd6;
            3'd1: gap_lut = 3'd4;
            3'd2: gap_lut = 3'd3;
            3'd3: gap_lut = 3'd2;
            3'd4: gap_lut = 3'd1;
            default: gap_lut = 3'd1;
        endcase
    endfunction

    // Max pair index for given gap: last i such that i+gap < 8 -> i <= 7-gap
    function automatic logic [2:0] max_pair_idx(input logic [2:0] g);
        max_pair_idx = 3'd7 - g;
    endfunction

    // Generate pair indices for up to 4 parallel comparisons
    always_comb begin
        // Default
        for (int k = 0; k < 4; k++) begin
            idx_a[k]    = 3'd0;
            idx_b[k]    = 3'd0;
            valid_pair[k] = 1'b0;
            cmp_do_swap[k] = 1'b0;
        end
        swap_any = 1'b0;

        if (state == COMPARE_GAP) begin
            // Lane 0..3 handle pair_idx + lane*gap
            for (int lane = 0; lane < 4; lane++) begin
                logic [3:0] ia_ext;
                logic [3:0] ib_ext;
                ia_ext = pair_idx + (gap * lane);
                ib_ext = ia_ext + gap;

                if (ia_ext < 8 && ib_ext < 8) begin
                    idx_a[lane]      = ia_ext[2:0];
                    idx_b[lane]      = ib_ext[2:0];
                    valid_pair[lane] = 1'b1;
                    cmp_do_swap[lane]= (arr[ia_ext[2:0]] > arr[ib_ext[2:0]]);
                    if (arr[ia_ext[2:0]] > arr[ib_ext[2:0]]) begin
                        swap_any = 1'b1;
                    end
                end
            end
        end
    end

    // Sequential state machine and registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            gap_idx  <= 3'd0;
            gap      <= 3'd6;
            pair_idx <= 3'd0;
            swapped  <= 1'b0;
            done     <= 1'b0;

            for (int i = 0; i < 8; i++) begin
                arr[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Prepare to load
                        gap_idx  <= 3'd0;
                        gap      <= gap_lut(3'd0);
                        pair_idx <= 3'd0;
                        swapped  <= 1'b0;
                    end
                end

                LOAD: begin
                    // Unpack data_in into arr[0]..arr[7]
                    arr[0] <= data_in[7:0];
                    arr[1] <= data_in[15:8];
                    arr[2] <= data_in[23:16];
                    arr[3] <= data_in[31:24];
                    arr[4] <= data_in[39:32];
                    arr[5] <= data_in[47:40];
                    arr[6] <= data_in[55:48];
                    arr[7] <= data_in[63:56];

                    // Initialize for first gap pass
                    gap_idx  <= 3'd0;
                    gap      <= gap_lut(3'd0);
                    pair_idx <= 3'd0;
                    swapped  <= 1'b0;
                end

                COMPARE_GAP: begin
                    // Comparisons are combinational; no register changes here
                end

                SWAP_IF_NEEDED: begin
                    // Perform swaps for all valid lanes that require swapping
                    for (int lane = 0; lane < 4; lane++) begin
                        if (valid_pair[lane] && cmp_do_swap[lane]) begin
                            logic [7:0] tmp;
                            tmp                      = arr[idx_a[lane]];
                            arr[idx_a[lane]]         = arr[idx_b[lane]];
                            arr[idx_b[lane]]         = tmp;
                        end
                    end
                    // Update swapped flag if any swap happened this cycle
                    if (swap_any)
                        swapped <= 1'b1;
                end

                NEXT_PAIR: begin
                    // Advance pair_idx by 4*gap for next batch of parallel comparisons
                    logic [3:0] next_pi_ext;
                    next_pi_ext = pair_idx + (gap << 2); // pair_idx + 4*gap
                    pair_idx    <= next_pi_ext[2:0];
                end

                UPDATE_GAP: begin
                    // Move to next gap in sequence
                    gap_idx  <= gap_idx + 3'd1;
                    gap      <= gap_lut(gap_idx + 3'd1);
                    pair_idx <= 3'd0;
                    swapped  <= 1'b0;
                end

                CHECK_SWAPPED: begin
                    // No sequential updates here; decision in next_state logic
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end

                default: begin
                    // Should not occur
                end
            endcase
        end
    end

    // Next-state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
            end

            LOAD: begin
                next_state = COMPARE_GAP;
            end

            COMPARE_GAP: begin
                // If there are no valid pairs from this pair_idx, move to next phase
                if (!valid_pair[0] && !valid_pair[1] && !valid_pair[2] && !valid_pair[3]) begin
                    next_state = CHECK_SWAPPED;
                end else begin
                    next_state = SWAP_IF_NEEDED;
                end
            end

            SWAP_IF_NEEDED: begin
                next_state = NEXT_PAIR;
            end

            NEXT_PAIR: begin
                // If next pair_idx exceeds max index for this gap, finish this gap pass
                if ((pair_idx + (gap << 2)) > max_pair_idx(gap)) begin
                    next_state = CHECK_SWAPPED;
                end else begin
                    next_state = COMPARE_GAP;
                end
            end

            CHECK_SWAPPED: begin
                if (gap_idx == 3'd4) begin
                    // Last gap (1) done
                    // If no swaps in this final pass, sorting complete
                    if (!swapped)
                        next_state = DONE_STATE;
                    else
                        // If swapped with gap=1, we must repeat gap=1
                        next_state = UPDATE_GAP; // UPDATE_GAP will re-set gap_idx+1 but clamp via lut
                end else begin
                    // For gaps > 1, always proceed to next gap regardless of swaps
                    next_state = UPDATE_GAP;
                end
            end

            UPDATE_GAP: begin
                // If we just advanced beyond last defined gap, clamp to gap=1 for final iterations
                if (gap_idx >= 3'd4) begin
                    // Stay at gap=1 until sorted (standard comb sort tail with gap=1)
                    next_state = COMPARE_GAP;
                end else begin
                    next_state = COMPARE_GAP;
                end
            end

            DONE_STATE: begin
                // Remain in DONE until a new start pulse
                if (start)
                    next_state = LOAD;
                else
                    next_state = DONE_STATE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Pack output
    always_comb begin
        data_out = {
            arr[7],
            arr[6],
            arr[5],
            arr[4],
            arr[3],
            arr[2],
            arr[1],
            arr[0]
        };
    end

endmodule