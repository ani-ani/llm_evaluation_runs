module kth_element_finder(
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
    input [3:0] k,
    input [3:0] array_size,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] COMPARE = 4'd2;
    localparam [3:0] SWAP = 4'd3;
    localparam [3:0] CHECK_COMPLETE = 4'd4;
    localparam [3:0] OUTPUT = 4'd5;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] arr_internal [0:7];
    reg [3:0] pass_count;
    reg [3:0] compare_index;
    reg [3:0] cycle_count;
    reg swap_flag;
    reg [7:0] temp;

    // Constants
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            pass_count <= 4'd0;
            compare_index <= 4'd0;
            cycle_count <= 8'd0;
            swap_flag <= 1'b0;

            // Initialize array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                arr_internal[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load input array into internal registers
                    arr_internal[0] <= arr_0;
                    arr_internal[1] <= arr_1;
                    arr_internal[2] <= arr_2;
                    arr_internal[3] <= arr_3;
                    arr_internal[4] <= arr_4;
                    arr_internal[5] <= arr_5;
                    arr_internal[6] <= arr_6;
                    arr_internal[7] <= arr_7;

                    pass_count <= 4'd0;
                    compare_index <= 4'd0;
                    swap_flag <= 1'b0;
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we need to swap
                    if (arr_internal[compare_index] > arr_internal[compare_index + 1]) begin
                        swap_flag <= 1'b1;
                        next_state <= SWAP;
                    end else begin
                        swap_flag <= 1'b0;
                        next_state <= CHECK_COMPLETE;
                    end
                end

                SWAP: begin
                    // Perform swap
                    temp <= arr_internal[compare_index];
                    arr_internal[compare_index] <= arr_internal[compare_index + 1];
                    arr_internal[compare_index + 1] <= temp;
                    next_state <= CHECK_COMPLETE;
                end

                CHECK_COMPLETE: begin
                    // Move to next comparison
                    compare_index <= compare_index + 4'd1;
                    
                    // Check if pass is complete
                    if (compare_index >= (array_size - pass_count - 4'd1)) begin
                        compare_index <= 4'd0;
                        
                        // Check if all passes are complete
                        if (pass_count >= (array_size - 4'd1)) begin
                            next_state <= OUTPUT;
                        end else begin
                            pass_count <= pass_count + 4'd1;
                            next_state <= COMPARE;
                        end
                    end else begin
                        next_state <= COMPARE;
                    end
                end

                OUTPUT: begin
                    // Output the kth smallest element (k-1 index)
                    result <= arr_internal[k - 4'd1];
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule