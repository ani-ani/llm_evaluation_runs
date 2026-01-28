module order_by_points (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] DONE = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [7:0] arr_reg [0:7];      // Input array storage
    reg [7:0] arr_tmp [0:7];      // Working array for sorting
    reg [4:0] digit_sum [0:7];    // Store digit sums (0-27 fits in 5 bits)
    
    // Loop counters
    reg [2:0] pass_counter;       // 7 passes (0-6)
    reg [2:0] idx_counter;        // 0-7 for element comparison
    reg [2:0] i;                  // General purpose counter
    reg [2:0] digit_idx;          // For digit extraction
    
    // Temporary storage for digit extraction
    reg signed [7:0] num_temp;
    reg [4:0] abs_value;
    reg [4:0] temp_sum;
    reg [2:0] digit;
    
    // Cycle counter for timing
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;
    
    // Helper: Extract digits from 8-bit signed number
    // Returns sum of decimal digit values (ignoring sign)
    function [4:0] get_digit_sum;
        input signed [7:0] num;
        reg signed [7:0] temp_num;
        reg [4:0] sum;
        reg [2:0] d;
        begin
            temp_num = num;
            sum = 5'd0;
            
            // Handle sign by taking absolute value
            if (temp_num < 0) begin
                temp_num = -temp_num;  // Convert to positive
            end
            
            // Extract decimal digits
            // Hundreds (only 1 possible: 1 for 100+)
            if (temp_num >= 8'd100) begin
                sum = sum + 5'd1;
                temp_num = temp_num - 8'd100;
            end
            
            // Tens
            d = temp_num / 8'd10;
            sum = sum + d;
            temp_num = temp_num - (d * 8'd10);
            
            // Ones
            sum = sum + temp_num[2:0];
            
            get_digit_sum = sum;
        end
    endfunction

    integer j;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 7'd0;
            pass_counter <= 3'd0;
            idx_counter <= 3'd0;
            
            // Clear arrays
            for (j = 0; j < 8; j = j + 1) begin
                result[j] <= 8'd0;
                arr_reg[j] <= 8'd0;
                arr_tmp[j] <= 8'd0;
                digit_sum[j] <= 5'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 7'd0;
                    pass_counter <= 3'd0;
                    idx_counter <= 3'd0;
                    
                    if (start) begin
                        state <= LOAD;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Load input array into internal registers
                    for (j = 0; j < 8; j = j + 1) begin
                        arr_reg[j] <= arr[j];
                        arr_tmp[j] <= arr[j];
                    end
                    
                    // Compute digit sums for all elements
                    digit_sum[0] <= get_digit_sum(arr[0]);
                    digit_sum[1] <= get_digit_sum(arr[1]);
                    digit_sum[2] <= get_digit_sum(arr[2]);
                    digit_sum[3] <= get_digit_sum(arr[3]);
                    digit_sum[4] <= get_digit_sum(arr[4]);
                    digit_sum[5] <= get_digit_sum(arr[5]);
                    digit_sum[6] <= get_digit_sum(arr[6]);
                    digit_sum[7] <= get_digit_sum(arr[7]);
                    
                    state <= SORT;
                    pass_counter <= 3'd0;
                    idx_counter <= 3'd0;
                end
                
                SORT: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    // Bubble sort: 7 passes for 8 elements
                    if (pass_counter < 3'd7) begin
                        // Compare adjacent pairs: (0,1), (1,2), ..., (6,7)
                        if (idx_counter < 3'd7) begin
                            // Compare digit sums
                            if (digit_sum[idx_counter] > digit_sum[idx_counter + 1]) begin
                                // Swap elements in arr_tmp
                                arr_tmp[idx_counter] <= arr_tmp[idx_counter + 1];
                                arr_tmp[idx_counter + 1] <= arr_tmp[idx_counter];
                                
                                // Swap digit sums as well
                                digit_sum[idx_counter] <= digit_sum[idx_counter + 1];
                                digit_sum[idx_counter + 1] <= digit_sum[idx_counter];
                            end
                            // If equal, do nothing (stable sort)
                            
                            idx_counter <= idx_counter + 3'd1;
                        end else begin
                            // End of current pass
                            idx_counter <= 3'd0;
                            pass_counter <= pass_counter + 3'd1;
                        end
                    end else begin
                        // All passes complete
                        state <= DONE;
                    end
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    // Copy sorted array to output
                    for (j = 0; j < 8; j = j + 1) begin
                        result[j] <= arr_tmp[j];
                    end
                    
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule