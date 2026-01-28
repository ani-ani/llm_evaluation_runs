module string_pair_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] strings [0:7],
    input [3:0] len,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] REVERSE = 2'd1;
    localparam [1:0] COMPARE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal registers
    reg [2:0] i_reg, j_reg, k_reg;
    reg [7:0] reversed_string [0:7];
    reg [7:0] current_char, reversed_char;
    reg match_found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            k_reg <= 3'd0;
            match_found <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 4'd0;
                    i_reg <= 3'd0;
                    j_reg <= 3'd0;
                    k_reg <= 3'd0;
                    match_found <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        next_state <= REVERSE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                REVERSE: begin
                    // Reverse string_i
                    if (k_reg < 8'd8) begin
                        current_char <= strings[i_reg][k_reg];
                        reversed_string[i_reg][7 - k_reg] <= current_char;
                        k_reg <= k_reg + 3'd1;
                        next_state <= REVERSE;
                    end else begin
                        k_reg <= 3'd0;
                        j_reg <= i_reg;
                        next_state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Compare string_j with reversed_string_i
                    if (k_reg < 8'd8) begin
                        current_char <= strings[j_reg][k_reg];
                        reversed_char <= reversed_string[i_reg][k_reg];
                        
                        if (current_char != reversed_char) begin
                            match_found <= 1'b0;
                        end
                        
                        k_reg <= k_reg + 3'd1;
                        next_state <= COMPARE;
                    end else begin
                        // Check if all characters matched
                        if (match_found) begin
                            result <= result + 4'd1;
                        end
                        
                        // Move to next j
                        j_reg <= j_reg + 3'd1;
                        k_reg <= 3'd0;
                        match_found <= 1'b1; // Assume match until proven otherwise
                        
                        // Check if we've compared all j for current i
                        if (j_reg >= len) begin
                            i_reg <= i_reg + 3'd1;
                            
                            // Check if we've processed all i
                            if (i_reg >= len - 4'd1) begin
                                next_state <= DONE_STATE;
                            end else begin
                                next_state <= REVERSE;
                            end
                        end else begin
                            next_state <= COMPARE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Default state transition
    always @(*) begin
        next_state = state;
    end

endmodule