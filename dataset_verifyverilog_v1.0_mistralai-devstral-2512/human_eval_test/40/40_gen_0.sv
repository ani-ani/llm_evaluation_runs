module TripleZeroSum(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] arr [0:15],
    input [3:0] len,
    output reg result,
    output reg done
);

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] SEARCH = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] i_reg, j_reg, left_reg, right_reg;
    reg signed [15:0] sorted_arr [0:15];
    reg found;
    reg busy;

    // Sorting network parameters
    localparam [3:0] MAX_LEN = 4'd16;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Load array into internal registers
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            left_reg <= 4'd0;
            right_reg <= 4'd0;
            found <= 1'b0;
            for (k = 0; k < 16; k = k + 1) begin
                sorted_arr[k] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && !busy) begin
                        next_state <= LOAD;
                        busy <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load array into sorted_arr
                    for (k = 0; k < 16; k = k + 1) begin
                        sorted_arr[k] <= arr[k];
                    end
                    next_state <= SORT;
                end

                SORT: begin
                    // Bubble sort implementation
                    reg [3:0] m, n;
                    reg signed [15:0] temp;
                    
                    // Simple bubble sort for small array
                    for (m = 0; m < len - 1; m = m + 1) begin
                        for (n = 0; n < len - m - 1; n = n + 1) begin
                            if (sorted_arr[n] > sorted_arr[n + 1]) begin
                                temp <= sorted_arr[n];
                                sorted_arr[n] <= sorted_arr[n + 1];
                                sorted_arr[n + 1] <= temp;
                            end
                        end
                    end
                    
                    next_state <= SEARCH;
                    i_reg <= 4'd0;
                    j_reg <= 4'd0;
                    left_reg <= 4'd0;
                    right_reg <= len - 1;
                    found <= 1'b0;
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've found a triple
                    if (found) begin
                        next_state <= DONE_STATE;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end else begin
                        // Two-pointer search
                        reg signed [16:0] sum;
                        
                        // Initialize for new i
                        if (i_reg == 4'd0 && j_reg == 4'd0) begin
                            j_reg <= i_reg + 1;
                            left_reg <= j_reg + 1;
                            right_reg <= len - 1;
                        end
                        
                        // Check current triple
                        sum = sorted_arr[i_reg] + sorted_arr[j_reg] + sorted_arr[left_reg];
                        
                        if (sum == 17'd0 && i_reg < j_reg && j_reg < left_reg) begin
                            found <= 1'b1;
                            next_state <= DONE_STATE;
                        end else if (left_reg < right_reg) begin
                            if (sum < 17'd0) begin
                                left_reg <= left_reg + 1;
                            end else begin
                                right_reg <= right_reg - 1;
                            end
                        end else begin
                            // Move to next j
                            j_reg <= j_reg + 1;
                            if (j_reg >= len - 1) begin
                                // Move to next i
                                i_reg <= i_reg + 1;
                                j_reg <= i_reg + 1;
                                left_reg <= j_reg + 1;
                                right_reg <= len - 1;
                            end else begin
                                left_reg <= j_reg + 1;
                                right_reg <= len - 1;
                            end
                        end
                        
                        // Check if we've exhausted all possibilities
                        if (i_reg >= len - 2) begin
                            next_state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    result <= found;
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule