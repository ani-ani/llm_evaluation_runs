module sum_non_repeated_elements(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] SORTING     = 2'd1;
    localparam [1:0] SUMMING     = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    reg [1:0] state;
    
    // Sorting registers
    reg [7:0] sorted_array [0:7];
    reg [2:0] pass_counter; // 0-6
    reg [2:0] comp_counter; // 0-6 (relative to pass)
    reg swap_flag;
    reg [7:0] temp_hold;
    
    // Summation registers
    reg [2:0] sum_index;
    reg [15:0] sum;
    reg [7:0] prev_element;
    
    // Safety counter
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize ALL registers
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            
            // Initialize array elements individually
            sorted_array[0] <= 8'd0;
            sorted_array[1] <= 8'd0;
            sorted_array[2] <= 8'd0;
            sorted_array[3] <= 8'd0;
            sorted_array[4] <= 8'd0;
            sorted_array[5] <= 8'd0;
            sorted_array[6] <= 8'd0;
            sorted_array[7] <= 8'd0;
            
            // Counters/temps
            pass_counter <= 3'd0;
            comp_counter <= 3'd0;
            swap_flag <= 1'b0;
            temp_hold <= 8'd0;
            
            sum_index <= 3'd0;
            sum <= 16'd0;
            prev_element <= 8'd0;
            
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    sum_index <= 3'd0;
                    sum <= 16'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load input array into working register
                        sorted_array[0] <= arr_0;
                        sorted_array[1] <= arr_1;
                        sorted_array[2] <= arr_2;
                        sorted_array[3] <= arr_3;
                        sorted_array[4] <= arr_4;
                        sorted_array[5] <= arr_5;
                        sorted_array[6] <= arr_6;
                        sorted_array[7] <= arr_7;
                        
                        state <= SORTING;
                        pass_counter <= 3'd0;
                        comp_counter <= 3'd0;
                    end
                end
                
                SORTING: begin
                    comp_counter <= comp_counter + 3'd1;
                    
                    // Compare adjacent elements
                    if (sorted_array[comp_counter] > sorted_array[comp_counter + 3'd1]) begin
                        // Perform swap
                        temp_hold <= sorted_array[comp_counter];
                        sorted_array[comp_counter] <= sorted_array[comp_counter + 3'd1];
                        sorted_array[comp_counter + 3'd1] <= temp_hold;
                    end
                    
                    // Current pass completion check
                    if (comp_counter >= (3'd6 - pass_counter)) begin
                        comp_counter <= 3'd0;
                        pass_counter <= pass_counter + 3'd1;
                        
                        // All passes completed
                        if (pass_counter >= 3'd6) begin
                            state <= SUMMING;
                            sum_index <= 3'd0;
                            // Initialize prev_element with first sorted element
                            prev_element <= sorted_array[0];
                        end
                    end
                    
                    // Overflow protection
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end
                
                SUMMING: begin
                    /* Logic:
                        1. Sum elements that differ from their successor
                        2. Always include last element
                    */
                    sum_index <= sum_index + 3'd1;
                    
                    if (sum_index < 3'd7) begin
                        if (sorted_array[sum_index] != sorted_array[sum_index + 3'd1]) begin
                            sum <= sum + sorted_array[sum_index];
                        end
                        prev_element <= sorted_array[sum_index];
                    end else if (sum_index == 3'd7) begin
                        // Add the last element (always unique)
                        sum <= sum + sorted_array[sum_index];
                        state <= DONE_STATE;
                    end
                    
                    // Overflow protection
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule