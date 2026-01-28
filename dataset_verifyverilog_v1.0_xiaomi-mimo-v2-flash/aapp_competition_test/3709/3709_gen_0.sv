module interesting_problemset (
    input clk,
    input rst_n,
    input start,
    input [3:0] prob_type,
    input valid_in,
    input finish_in,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD_INPUTS = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [15:0] exists; // Tracks which problem types (0-15) have been seen
    reg [4:0] i_counter; // Counter for outer loop (1 to 15)
    reg [4:0] j_counter; // Counter for inner loop (i+1 to 15)
    reg found_valid; // Flag if a valid pair/subset was found
    reg start_calc; // Flag to trigger calculation phase
    reg load_done; // Flag indicating input loading is complete
    reg [3:0] i_type; // Store current type i
    reg [3:0] j_type; // Store current type j

    // Integer for loop
    integer k;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            exists <= 16'd0;
            i_counter <= 5'd0;
            j_counter <= 5'd0;
            found_valid <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            start_calc <= 1'b0;
            load_done <= 1'b0;
            i_type <= 4'd0;
            j_type <= 4'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    found_valid <= 1'b0;
                    start_calc <= 1'b0;
                    load_done <= 1'b0;
                    i_counter <= 5'd0;
                    j_counter <= 5'd0;
                    exists <= 16'd0;
                end

                LOAD_INPUTS: begin
                    if (valid_in) begin
                        exists[prob_type] <= 1'b1;
                    end
                    if (finish_in) begin
                        load_done <= 1'b1;
                    end
                end

                CALCULATE: begin
                    // 1. Check for type 0 (single problem)
                    if (i_counter == 5'd0) begin
                        if (exists[0]) begin
                            found_valid <= 1'b1;
                        end
                        i_counter <= 5'd1;
                    end else if (!found_valid) begin
                        // 2. Check pairs (i, j) where i > 0
                        if (i_counter <= 5'd15) begin
                            if (exists[i_counter]) begin
                                // Inner loop logic
                                if (j_counter == 5'd0) begin
                                    // Start inner loop for this i
                                    j_counter <= i_counter + 5'd1;
                                end else if (j_counter <= 5'd15) begin
                                    // Increment j
                                    j_counter <= j_counter + 5'd1;
                                end
                            end else begin
                                // i_counter doesn't exist, move to next i
                                i_counter <= i_counter + 5'd1;
                                j_counter <= 5'd0;
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (found_valid) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Combinational logic for next state and calculation result
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_INPUTS;
                end
            end

            LOAD_INPUTS: begin
                // Wait for finish_in to transition
                if (finish_in) begin
                    next_state = CALCULATE;
                end else begin
                    next_state = LOAD_INPUTS;
                end
            end

            CALCULATE: begin
                // Check if calculation is complete
                if (found_valid) begin
                    // Early exit if valid subset found
                    next_state = FINISH;
                end else if (i_counter > 5'd15) begin
                    // Checked all possibilities, no valid subset found
                    next_state = FINISH;
                end else if (i_counter == 5'd0) begin
                    // Still processing type 0 check
                    next_state = CALCULATE;
                end else begin
                    // Processing pairs
                    if (exists[i_counter]) begin
                        if (j_counter > 5'd15) begin
                            // Inner loop finished for current i, move to next i
                            next_state = CALCULATE; // Continue loop
                        end else if (j_counter > 5'd0) begin
                            // Check current pair (i, j)
                            if (exists[j_counter] && ((i_counter & j_counter) == 0)) begin
                                found_valid = 1'b1; // Combinational update for immediate transition
                                next_state = FINISH;
                            end else begin
                                next_state = CALCULATE;
                            end
                        end else begin
                            // Waiting for j loop to start
                            next_state = CALCULATE;
                        end
                    end else begin
                        // i doesn't exist, move to next i
                        next_state = CALCULATE;
                    end
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule