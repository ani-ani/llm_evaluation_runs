module voodoo_counter (
    input wire clk,              // Clock, rising edge
    input wire rst_n,            // Active-low synchronous reset
    input wire start,            // Start pulse, assert for 1 cycle
    input wire [2:0] N,          // Number of valid array elements (1..8)
    input wire [7:0] P,          // Threshold price
    input wire [7:0] arr_0, arr_1, arr_2, arr_3,
                     arr_4, arr_5, arr_6, arr_7, // Array values (N valid)
    output reg [5:0] result,     // Count of subarrays with average >= P
    output reg done              // Asserted high for 1 cycle when result is valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PREFIX = 3'd2;
    localparam [2:0] COUNT_INIT = 3'd3;
    localparam [2:0] COUNT_LOOP = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state;
    reg [2:0] state_next;
    
    // Internal registers
    reg [11:0] prefix_reg [0:8]; // 13-bit signed for prefix sums (+/- 4096 range)
    reg signed [8:0] b_i;        // arr_i - P (9-bit signed)
    reg signed [12:0] temp_sum;  // Temporary sum for prefix calculation
    reg [3:0] i_cnt;             // Outer loop counter (0 to N)
    reg [3:0] j_cnt;             // Inner loop counter (i+1 to N)
    reg [5:0] temp_result;       // Accumulator for count
    reg [2:0] calc_idx;          // Index for prefix calculation (0 to N)
    reg [3:0] cycle_count;       // Prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd15;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 6'd0;
            done <= 1'b0;
            i_cnt <= 4'd0;
            j_cnt <= 4'd0;
            temp_result <= 6'd0;
            calc_idx <= 3'd0;
            b_i <= 9'sd0;
            temp_sum <= 13'sd0;
            cycle_count <= 4'd0;
            for (i = 0; i < 9; i = i + 1) begin
                prefix_reg[i] <= 12'sd0;
            end
        end else begin
            state <= state_next;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state_next <= INIT;
                    end else begin
                        state_next <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize prefix[0] = 0
                    prefix_reg[0] <= 12'sd0;
                    calc_idx <= 3'd0;
                    state_next <= PREFIX;
                end

                PREFIX: begin
                    // Compute b_i = arr_i - P
                    // Select correct array element based on calc_idx
                    case (calc_idx)
                        3'd0: b_i <= {1'b0, arr_0} - {1'b0, P};
                        3'd1: b_i <= {1'b0, arr_1} - {1'b0, P};
                        3'd2: b_i <= {1'b0, arr_2} - {1'b0, P};
                        3'd3: b_i <= {1'b0, arr_3} - {1'b0, P};
                        3'd4: b_i <= {1'b0, arr_4} - {1'b0, P};
                        3'd5: b_i <= {1'b0, arr_5} - {1'b0, P};
                        3'd6: b_i <= {1'b0, arr_6} - {1'b0, P};
                        3'd7: b_i <= {1'b0, arr_7} - {1'b0, P};
                        default: b_i <= 9'sd0;
                    endcase
                    
                    // Next cycle: compute prefix sum
                    state_next <= state;
                    
                    // Check if done with prefix computation
                    if (calc_idx >= N) begin
                        state_next <= COUNT_INIT;
                    end
                end

                default: begin
                    // Special handling for prefix calculation continuation
                    // We need a separate state to add b_i to prefix
                    if (state == PREFIX && calc_idx < N) begin
                        // Add b_i to previous prefix
                        temp_sum <= prefix_reg[calc_idx] + b_i;
                        prefix_reg[calc_idx + 1] <= prefix_reg[calc_idx] + b_i;
                        calc_idx <= calc_idx + 3'd1;
                        state_next <= PREFIX;
                    end
                    else if (state == COUNT_INIT) begin
                        i_cnt <= 4'd0;
                        j_cnt <= 4'd1;
                        temp_result <= 6'd0;
                        cycle_count <= 4'd0;
                        state_next <= COUNT_LOOP;
                    end
                    else if (state == COUNT_LOOP) begin
                        // Check if we're done
                        if (i_cnt >= N || cycle_count >= MAX_CYCLES) begin
                            result <= temp_result;
                            state_next <= DONE;
                        end
                        else if (j_cnt > N) begin
                            // Inner loop done, increment outer
                            i_cnt <= i_cnt + 4'd1;
                            j_cnt <= i_cnt + 4'd2;
                            cycle_count <= cycle_count + 4'd1;
                        end
                        else begin
                            // Compare prefix[i] <= prefix[j]
                            if (prefix_reg[i_cnt] <= prefix_reg[j_cnt]) begin
                                temp_result <= temp_result + 6'd1;
                            end
                            j_cnt <= j_cnt + 4'd1;
                            cycle_count <= cycle_count + 4'd1;
                        end
                    end
                    else if (state == DONE) begin
                        done <= 1'b1;
                        state_next <= IDLE;
                    end
                    else begin
                        state_next <= IDLE;
                    end
                end
            endcase
        end
    end

    // Combinational logic for state transitions
    always @(*) begin
        state_next = IDLE;
        case (state)
            IDLE: begin
                if (start) state_next = INIT;
                else state_next = IDLE;
            end
            INIT: state_next = PREFIX;
            PREFIX: begin
                if (calc_idx >= N) state_next = COUNT_INIT;
                else state_next = PREFIX;
            end
            COUNT_INIT: state_next = COUNT_LOOP;
            COUNT_LOOP: begin
                if (i_cnt >= N || cycle_count >= MAX_CYCLES) state_next = DONE;
                else if (j_cnt > N) state_next = COUNT_LOOP;
                else state_next = COUNT_LOOP;
            end
            DONE: state_next = IDLE;
            default: state_next = IDLE;
        endcase
    end

endmodule