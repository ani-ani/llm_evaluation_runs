module SortArray (
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr_in [0:7],
    output reg [7:0] result [0:7],
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_LEN = 3'd1;
    localparam [2:0] CALC_SUM = 3'd2;
    localparam [2:0] SORT = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [7:0] buffer [0:7];
    reg [3:0] i, j;
    reg [3:0] len_reg;
    reg [8:0] sum_val;
    reg sort_ascending;
    reg swap_needed;
    reg [7:0] temp_val;
    reg [7:0] temp_val2;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;
    
    integer k;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            for (k = 0; k < 8; k = k + 1) begin
                result[k] <= 8'd0;
                buffer[k] <= 8'd0;
            end
            len_reg <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            cycle_count <= 4'd0;
            sort_ascending <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        // Copy input to buffer
                        for (k = 0; k < 8; k = k + 1) begin
                            buffer[k] <= arr_in[k];
                        end
                        len_reg <= len;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
                
                CHECK_LEN: begin
                    if (len_reg <= 4'd1) begin
                        // 0 or 1 element, copy buffer to result
                        for (k = 0; k < 8; k = k + 1) begin
                            result[k] <= buffer[k];
                        end
                        next_state <= FINISH;
                    end
                end
                
                CALC_SUM: begin
                    // Calculate sum of first and last valid elements
                    sum_val <= {1'b0, buffer[0]} + {1'b0, buffer[len_reg - 1]};
                    sort_ascending <= sum_val[0]; // Ascending if odd
                    i <= 4'd0;
                    j <= 4'd0;
                end
                
                SORT: begin
                    // Bubble sort
                    if (i < len_reg - 1) begin
                        if (j < len_reg - i - 1) begin
                            // Compare adjacent elements
                            if (sort_ascending) begin
                                swap_needed <= (buffer[j] > buffer[j + 1]);
                            end else begin
                                swap_needed <= (buffer[j] < buffer[j + 1]);
                            end
                            temp_val <= buffer[j];
                            temp_val2 <= buffer[j + 1];
                            j <= j + 1;
                        end else begin
                            // Next outer iteration
                            i <= i + 1;
                            j <= 4'd0;
                            swap_needed <= 1'b0;
                        end
                        cycle_count <= cycle_count + 4'd1;
                    end else begin
                        // Sorting complete
                        // Copy buffer to result
                        for (k = 0; k < 8; k = k + 1) begin
                            result[k] <= buffer[k];
                        end
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_LEN;
                end
            end
            
            CHECK_LEN: begin
                if (len_reg <= 4'd1) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALC_SUM;
                end
            end
            
            CALC_SUM: begin
                next_state = SORT;
            end
            
            SORT: begin
                // Check if sorting complete or timed out
                if (cycle_count >= MAX_CYCLES) begin
                    // Force finish if max cycles reached
                    next_state = FINISH;
                end else if (i >= len_reg - 1) begin
                    next_state = FINISH;
                end else begin
                    next_state = SORT;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Swap logic (synchronous)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 8; k = k + 1) begin
                buffer[k] <= 8'd0;
            end
        end else begin
            if (state == SORT && j > 0 && swap_needed) begin
                buffer[j - 1] <= temp_val2;
                buffer[j] <= temp_val;
            end
        end
    end
endmodule