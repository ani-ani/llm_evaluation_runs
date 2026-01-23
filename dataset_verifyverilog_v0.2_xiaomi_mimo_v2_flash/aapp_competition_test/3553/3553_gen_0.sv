module shortest_subarray_solver(
    input clk,
    input rst_n,
    input start,
    input query_type,
    input [4:0] pos,
    input [1:0] new_value,
    output reg result_valid,
    output reg [5:0] shortest_length,
    output reg processing_done
);

    // Internal array storage (16 elements, 2 bits each)
    reg [1:0] array_reg [0:15];
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam INIT_SCAN = 3'b001;
    localparam OUTER_LOOP = 3'b010;
    localparam INNER_LOOP = 3'b011;
    localparam UPDATE_BEST = 3'b100;
    localparam DONE = 3'b101;
    
    // State and control registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Loop counters and registers
    reg [3:0] i;  // Outer loop index (0 to 15)
    reg [3::0] j;  // Inner loop index (0 to 15)
    reg [3:0] start_idx;  // Current start position for scan
    reg [3:0] end_idx;    // Current end position for scan
    
    // Counters for values 1-4 in current window
    reg [3:0] count_1;
    reg [3:0] count_2;
    reg [3:0] count_3;
    reg [3:0] count_4;
    
    // Best result tracking
    reg [5:0] best_length;
    reg [3:0] best_start;
    reg [3:0] best_end;
    reg found_valid;
    
    // Temporary registers for window calculation
    reg [3:0] temp_len;
    
    // Track if all values present
    wire has_all = (count_1 > 0) && (count_2 > 0) && (count_3 > 0) && (count_4 > 0);
    
    integer idx;
    
    // Main state transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // Initialize array to all 1s
            for (idx = 0; idx < 16; idx = idx + 1) begin
                array_reg[idx] <= 2'b01;  // Value 1
            end
            // Reset outputs
            result_valid <= 1'b0;
            shortest_length <= 6'd0;
            processing_done <= 1'b0;
            // Reset internal registers
            i <= 4'd0;
            j <= 4'd0;
            start_idx <= 4'd0;
            end_idx <= 4'd0;
            count_1 <= 4'd0;
            count_2 <= 4'd0;
            count_3 <= 4'd0;
            count_4 <= 4'd0;
            best_length <= 6'd63;
            found_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    processing_done <= 1'b0;
                    if (start) begin
                        if (query_type == 1'b0) begin
                            // UPDATE query
                            array_reg[pos] <= new_value;
                            processing_done <= 1'b1;
                            state <= DONE;
                        end else begin
                            // QUERY - start scanning
                            state <= INIT_SCAN;
                            best_length <= 6'd63;
                            found_valid <= 1'b0;
                        end
                    end
                end
                
                INIT_SCAN: begin
                    // Initialize for scan
                    i <= 4'd0;
                    j <= 4'd0;
                    start_idx <= 4'd0;
                    end_idx <= 4'd0;
                    count_1 <= 4'd0;
                    count_2 <= 4'd0;
                    count_3 <= 4'd0;
                    count_4 <= 4'd0;
                    state <= OUTER_LOOP;
                end
                
                OUTER_LOOP: begin
                    // Initialize window counts for new start position
                    count_1 <= 4'd0;
                    count_2 <= 4'd0;
                    count_3 <= 4'd0;
                    count_4 <= 4'd0;
                    j <= i;
                    state <= INNER_LOOP;
                end
                
                INNER_LOOP: begin
                    // Add current element to counts
                    case (array_reg[j])
                        2'b01: count_1 <= count_1 + 1;
                        2'b10: count_2 <= count_2 + 1;
                        2'b11: count_3 <= count_3 + 1;
                        2'b00: count_4 <= count_4 + 1;
                        default: begin
                            count_1 <= count_1;
                            count_2 <= count_2;
                            count_3 <= count_3;
                            count_4 <= count_4;
                        end
                    endcase
                    
                    // Check if window has all values
                    if (j > i || (j == i)) begin
                        // Update temp_len and check condition
                        if (has_all) begin
                            temp_len <= j - i + 1;
                            state <= UPDATE_BEST;
                        end else if (j == 4'd15) begin
                            // Reached end, move to next start
                            if (i == 4'd15) begin
                                state <= DONE;
                            end else begin
                                i <= i + 1;
                                state <= OUTER_LOOP;
                            end
                        end else begin
                            // Continue scanning
                            j <= j + 1;
                            state <= INNER_LOOP;
                        end
                    end
                end
                
                UPDATE_BEST: begin
                    // Update best length if better
                    if (temp_len < best_length) begin
                        best_length <= temp_len;
                        found_valid <= 1'b1;
                    end
                    
                    // Continue inner loop or move to next start
                    if (j == 4'd15) begin
                        // Reached end of array
                        if (i == 4'd15) begin
                            state <= DONE;
                        end else begin
                            i <= i + 1;
                            state <= OUTER_LOOP;
                        end
                    end else begin
                        // Continue scanning from next position
                        j <= j + 1;
                        state <= INNER_LOOP;
                    end
                end
                
                DONE: begin
                    if (found_valid) begin
                        shortest_length <= best_length;
                    end else begin
                        shortest_length <= 6'd63;  // Not found
                    end
                    result_valid <= 1'b1;
                    processing_done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule