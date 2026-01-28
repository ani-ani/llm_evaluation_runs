module ProductOfUnique(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SORTING    = 3'd1;
    localparam [2:0] FILTERING  = 3'd2;
    localparam [2:0] MULTIPLY   = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    // Registers
    reg [2:0] state;
    reg [7:0] sorted_arr [0:7];    // Sorted array
    reg [7:0] unique_arr [0:7];    // Array with duplicates removed
    reg [2:0] unique_count;        // Number of unique elements
    reg [31:0] prod_acc;           // Product accumulator
    reg [2:0] idx;                 // General purpose index
    reg [2:0] count;               // General purpose counter
    reg [2:0] cycle_count;         // Cycle counter for timeout
    reg zero_found;                // Flag for zero detection
    reg [7:0] mult_op_a;           // Multiplier operand A
    reg [7:0] mult_op_b;           // Multiplier operand B
    reg mult_valid;                // Multiplier input valid
    reg [31:0] mult_result;        // Multiplier output
    reg mult_done;                 // Multiplier done flag
    reg [2:0] mult_idx;            // Multiplier index
    
    // Initialize sorting variables
    reg sort_phase;                // 0 for odd phase, 1 for even phase
    reg [2:0] sort_start;          // Starting index for comparison
    reg [7:0] temp_val;            // Temp for swap
    reg comp_result;               // Comparison result
    
    // Temporary registers for pipeline
    reg [7:0] temp_arr [0:7];
    
    integer i;

    // Multiplier module (combinational)
    always @(*) begin
        mult_result = mult_op_a * mult_op_b;
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            zero_found <= 1'b0;
            unique_count <= 3'd0;
            prod_acc <= 32'd1;      // Start with 1 for multiplication
            idx <= 3'd0;
            count <= 3'd0;
            cycle_count <= 3'd0;
            mult_valid <= 1'b0;
            mult_idx <= 3'd0;
            sort_phase <= 1'b0;
            sort_start <= 3'd0;
            mult_op_a <= 8'd0;
            mult_op_b <= 8'd0;
            temp_val <= 8'd0;
            comp_result <= 1'b0;
            mult_done <= 1'b0;
            
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                sorted_arr[i] <= 8'd0;
                unique_arr[i] <= 8'd0;
                temp_arr[i] <= 8'd0;
            end
            
        end else begin
            
            // Default assignments
            done <= 1'b0;
            mult_valid <= 1'b0;
            
            case (state)
                
                IDLE: begin
                    prod_acc <= 32'd1;
                    zero_found <= 1'b0;
                    idx <= 3'd0;
                    count <= 3'd0;
                    cycle_count <= 3'd0;
                    sort_phase <= 1'b0;
                    sort_start <= 3'd0;
                    mult_idx <= 3'd0;
                    mult_done <= 1'b0;
                    
                    if (start) begin
                        // Copy input array to sorted_arr
                        sorted_arr[0] <= arr_0;
                        sorted_arr[1] <= arr_1;
                        sorted_arr[2] <= arr_2;
                        sorted_arr[3] <= arr_3;
                        sorted_arr[4] <= arr_4;
                        sorted_arr[5] <= arr_5;
                        sorted_arr[6] <= arr_6;
                        sorted_arr[7] <= arr_7;
                        
                        // Check for zero
                        if (arr_0 == 8'd0 || arr_1 == 8'd0 || arr_2 == 8'd0 || arr_3 == 8'd0 ||
                            arr_4 == 8'd0 || arr_5 == 8'd0 || arr_6 == 8'd0 || arr_7 == 8'd0) begin
                            zero_found <= 1'b1;
                        end
                        
                        // For len < 8, mark unused elements as max value for sorting
                        if (len < 4'd8) begin
                            for (i = len; i < 8; i = i + 1) begin
                                sorted_arr[i] <= 8'd255;
                            end
                        end
                        
                        state <= SORTING;
                        cycle_count <= 3'd0;
                    end
                end
                
                SORTING: begin
                    // Bubble sort implementation
                    // Compare adjacent pairs and swap if needed
                    cycle_count <= cycle_count + 3'd1;
                    
                    if (cycle_count < 3'd7) begin  // Max 7 passes for 8 elements
                        
                        // For each phase, iterate through indices
                        if (idx < 3'd7) begin
                            // Determine comparison pair based on phase
                            if (sort_phase == 1'b0) begin  // Odd phase
                                if (idx[0] == 1'b0) begin  // Even indices: 0-1, 2-3, 4-5, 6-7
                                    if (sorted_arr[idx] > sorted_arr[idx+1]) begin
                                        // Swap
                                        temp_val <= sorted_arr[idx];
                                        sorted_arr[idx] <= sorted_arr[idx+1];
                                        sorted_arr[idx+1] <= temp_val;
                                    end
                                end
                            end else begin  // Even phase
                                if (idx[0] == 1'b1) begin  // Odd indices: 1-2, 3-4, 5-6
                                    if (sorted_arr[idx] > sorted_arr[idx+1]) begin
                                        // Swap
                                        temp_val <= sorted_arr[idx];
                                        sorted_arr[idx] <= sorted_arr[idx+1];
                                        sorted_arr[idx+1] <= temp_val;
                                    end
                                end
                            end
                            idx <= idx + 3'd1;
                        end else begin
                            // Finished current phase
                            idx <= 3'd0;
                            sort_phase <= ~sort_phase;
                            // If completed both phases and reached enough passes, move to filtering
                            if (sort_phase == 1'b1 && cycle_count >= 3'd6) begin
                                state <= FILTERING;
                                idx <= 3'd0;
                                unique_count <= 3'd0;
                            end
                        end
                    end else begin
                        state <= FILTERING;
                        idx <= 3'd0;
                        unique_count <= 3'd0;
                    end
                end
                
                FILTERING: begin
                    // After sorting, filter out duplicates
                    // Only keep first instance of each value
                    if (idx < 3'd8) begin
                        if (idx == 3'd0) begin
                            // Always keep first element if within length
                            if (idx < len) begin
                                unique_arr[unique_count] <= sorted_arr[idx];
                                unique_count <= unique_count + 3'd1;
                            end
                        end else begin
                            // Compare with previous
                            if (idx < len && sorted_arr[idx] != sorted_arr[idx-1]) begin
                                unique_arr[unique_count] <= sorted_arr[idx];
                                unique_count <= unique_count + 3'd1;
                            end
                        end
                        idx <= idx + 3'd1;
                    end else begin
                        // Done filtering
                        if (zero_found) begin
                            // If any zero found, result is 0
                            result <= 32'd0;
                            state <= FINISH;
                        end else if (unique_count == 3'd0) begin
                            // No unique elements, result is 1 (product of empty set)
                            result <= 32'd1;
                            state <= FINISH;
                        end else begin
                            mult_idx <= 3'd0;
                            prod_acc <= 32'd1;
                            state <= MULTIPLY;
                        end
                    end
                end
                
                MULTIPLY: begin
                    // Multiply unique values sequentially
                    if (mult_idx < unique_count) begin
                        // Set up multiplication
                        mult_op_a <= prod_acc[7:0];      // Lower 8 bits of accumulator
                        mult_op_b <= unique_arr[mult_idx];
                        mult_valid <= 1'b1;
                        
                        // Wait one cycle for multiplication result
                        if (mult_done) begin
                            prod_acc <= mult_result;
                            mult_idx <= mult_idx + 3'd1;
                            mult_done <= 1'b0;
                        end else begin
                            mult_done <= 1'b1;
                        end
                    end else begin
                        // All multiplications done
                        result <= prod_acc;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
                
            endcase
        end
    end

endmodule