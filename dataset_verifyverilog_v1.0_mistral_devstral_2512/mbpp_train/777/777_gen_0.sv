module NonRepeatedSum(
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
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SORTING = 2'd1;
    localparam [1:0] SUMMING = 2'd2;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] sorted_arr [0:7];
    reg [15:0] sum;
    reg [7:0] pass_count;
    reg [7:0] comp_count;
    reg [7:0] sum_index;
    reg [7:0] temp;
    reg [7:0] prev_val;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    // Initialize array on reset
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            pass_count <= 8'd0;
            comp_count <= 8'd0;
            sum_index <= 8'd0;
            sum <= 16'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                sorted_arr[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load input array
                        sorted_arr[0] <= arr_0;
                        sorted_arr[1] <= arr_1;
                        sorted_arr[2] <= arr_2;
                        sorted_arr[3] <= arr_3;
                        sorted_arr[4] <= arr_4;
                        sorted_arr[5] <= arr_5;
                        sorted_arr[6] <= arr_6;
                        sorted_arr[7] <= arr_7;
                        next_state <= SORTING;
                        pass_count <= 8'd0;
                        comp_count <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                SORTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (pass_count < 8'd7) begin
                        if (comp_count < 8'd7) begin
                            // Bubble sort comparison
                            if (sorted_arr[comp_count] > sorted_arr[comp_count + 8'd1]) begin
                                // Swap
                                temp <= sorted_arr[comp_count];
                                sorted_arr[comp_count] <= sorted_arr[comp_count + 8'd1];
                                sorted_arr[comp_count + 8'd1] <= temp;
                            end
                            comp_count <= comp_count + 8'd1;
                        end else begin
                            comp_count <= 8'd0;
                            pass_count <= pass_count + 8'd1;
                        end
                    end else begin
                        // Sorting complete
                        next_state <= SUMMING;
                        sum_index <= 8'd0;
                        sum <= 16'd0;
                        prev_val <= 8'd0;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                SUMMING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (sum_index < 8'd8) begin
                        if (sum_index == 8'd0 || sorted_arr[sum_index] != prev_val) begin
                            // Add non-repeated element
                            sum <= sum + sorted_arr[sum_index];
                            prev_val <= sorted_arr[sum_index];
                        end
                        sum_index <= sum_index + 8'd1;
                    end else begin
                        // Summation complete
                        result <= sum;
                        done <= 1'b1;
                        next_state <= IDLE;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // Default next_state to IDLE
    always @(*) begin
        next_state = IDLE;
    end

endmodule