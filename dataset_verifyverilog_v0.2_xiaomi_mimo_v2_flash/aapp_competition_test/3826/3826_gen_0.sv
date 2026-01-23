module min_subsegment_removal(
    input clk,
    input rst_n,
    input start,
    input [2:0] n_in,
    input [7:0] arr_in,
    output reg [3:0] result,
    output reg done
);

    // Parameters and Constants
    localparam MAX_N = 8;
    localparam VAL_W = 8;
    localparam CNT_W = 2; // Frequency count width (max freq 3 is enough)
    localparam IDX_W = 3; // Index width for array access
    
    // State Encoding
    localparam IDLE = 4'd0;
    localparam LOAD = 4'd1;
    localparam INIT_DISTINCT = 4'd2;
    localparam LOOP_L = 4'd3;
    localparam CHECK_R = 4'd4;
    localparam UPDATE_RESULT = 4'd7;
    localparam INCREMENT_R = 4'd5;
    localparam INCREMENT_L = 4'd6;
    localparam DONE_STATE = 4'd8;

    // Internal registers and memory
    reg [3:0] state;
    reg [2:0] load_cnt;
    reg [2:0] l_idx;
    reg [2:0] r_idx;
    reg [2:0] n_reg;
    reg [2:0] check_idx;
    reg [1:0] check_phase; // 0: Clear RAM, 1: Check Distinctness
    
    // Memory for input array
    reg [7:0] mem [0:7];
    
    // Frequency RAM (256 x 2 bits)
    // Used as a "visited" flag for the current distinctness check
    reg [1:0] freq [0:255];
    
    // Helper signal for distinctness check
    wire check_duplicate;
    wire check_done;
    wire is_valid_idx;
    
    assign is_valid_idx = (check_idx < l_idx) || (check_idx > r_idx);
    assign check_duplicate = (freq[mem[check_idx]] == 1) && is_valid_idx;
    assign check_done = (check_idx == n_reg);
    
    // State Encoding
    localparam S_IDLE = 4'd0;
    localparam S_LOAD = 4'd1;
    localparam S_INIT_DISTINCT = 4'd2;
    localparam S_LOOP_L = 4'd3;
    localparam S_CHECK_R = 4'd4;
    localparam S_INCR_R = 4'd5;
    localparam S_INCR_L = 4'd6;
    localparam S_UPDATE_RESULT = 4'd7;
    localparam S_DONE = 4'd8;

    // State Transition and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
            load_cnt <= 0;
            l_idx <= 0;
            r_idx <= 0;
            check_idx <= 0;
            check_phase <= 0;
            n_reg <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        state <= S_LOAD;
                        load_cnt <= 0;
                        done <= 0;
                    end
                end

                S_LOAD: begin
                    // Capture input data sequentially
                    // Assuming arr_in holds the current element during load phase
                    mem[load_cnt] <= arr_in;
                    if (load_cnt == 3'd7) begin
                        n_reg <= n_in; // Use n_in to limit loops
                        state <= S_INIT_DISTINCT;
                    end else begin
                        load_cnt <= load_cnt + 1'b1;
                    end
                end

                S_INIT_DISTINCT: begin
                    // Initialize loop variables
                    l_idx <= 3'd0;
                    result <= 4'd8; // Initialize result to max possible length
                    state <= S_LOOP_L;
                end

                S_LOOP_L: begin
                    if (l_idx >= n_reg) begin
                        state <= S_DONE;
                    end else begin
                        r_idx <= l_idx; // Start r at l (smallest removal length)
                        check_phase <= 0; // Start with clearing RAM
                        check_idx <= 0;
                        state <= S_CHECK_R;
                    end
                end

                S_CHECK_R: begin
                    if (check_phase == 2'd0) begin
                        // Phase 0: Clear RAM for the values present in the array
                        // We write 0 to freq[mem[check_idx]]
                        freq[mem[check_idx]] <= 2'd0;
                        if (check_idx == n_reg - 1) begin
                            check_phase <= 2'd1;
                            check_idx <= 0;
                        end else begin
                            check_idx <= check_idx + 1'b1;
                        end
                    end else begin
                        // Phase 1: Check distinctness of remaining elements
                        if (check_duplicate) begin
                            // Duplicate found in remaining set
                            state <= S_INCR_R;
                        end else begin
                            if (check_done) begin
                                // All checked, no duplicates found
                                state <= S_UPDATE_RESULT;
                            end else begin
                                // Mark seen and continue
                                if (is_valid_idx) begin
                                    freq[mem[check_idx]] <= 2'd1;
                                end
                                check_idx <= check_idx + 1'b1;
                            end
                        end
                    end
                end

                S_INCR_R: begin
                    // Increment r_idx (increase length of removal)
                    r_idx <= r_idx + 1'b1;
                    if (r_idx == n_reg - 1) begin
                        // Tried all r for this l, go to next l
                        state <= S_INCR_L;
                    end else begin
                        // Try next r
                        check_phase <= 0;
                        check_idx <= 0;
                        state <= S_CHECK_R;
                    end
                end

                S_INCR_L: begin
                    l_idx <= l_idx + 1'b1;
                    state <= S_LOOP_L;
                end

                S_UPDATE_RESULT: begin
                    // Calculate length: r_idx - l_idx + 1
                    // Since we found a valid solution, update if it's smaller than current result
                    result <= (result < (r_idx - l_idx + 1)) ? result : (r_idx - l_idx + 1);
                    state <= S_INCR_L; // Move to next l
                end

                S_DONE: begin
                    done <= 1'b1;
                    // Stay in done state until reset
                end
            endcase
        end
    end
endmodule