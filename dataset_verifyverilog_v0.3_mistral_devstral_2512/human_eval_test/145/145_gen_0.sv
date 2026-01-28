module order_by_points(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] SORT = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [7:0] internal_arr [0:7];
    reg [4:0] digit_sum [0:7];
    reg [3:0] pass_counter;
    reg [3:0] element_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Digit sum calculation function
    function [4:0] calculate_digit_sum(input [7:0] num);
        reg [7:0] abs_num;
        reg [4:0] sum;
        integer i;
        
        abs_num = num[7] ? -num : num;  // Absolute value
        sum = 5'd0;
        
        for (i = 0; i < 3; i = i + 1) begin
            sum = sum + abs_num % 10;
            abs_num = abs_num / 10;
        end
        
        calculate_digit_sum = sum;
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                internal_arr[i] <= 8'd0;
                digit_sum[i] <= 5'd0;
                result[i] <= 8'd0;
            end
            pass_counter <= 4'd0;
            element_counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load input array and calculate digit sums
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        internal_arr[i] <= arr[i];
                        digit_sum[i] <= calculate_digit_sum(arr[i]);
                    end
                    pass_counter <= 4'd0;
                    element_counter <= 4'd0;
                    state <= SORT;
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Perform bubble sort pass
                    if (element_counter < 7) begin
                        // Compare adjacent elements
                        if (digit_sum[element_counter] > digit_sum[element_counter + 1]) begin
                            // Swap elements and their digit sums
                            reg [7:0] temp_val;
                            reg [4:0] temp_sum;
                            
                            temp_val = internal_arr[element_counter];
                            internal_arr[element_counter] <= internal_arr[element_counter + 1];
                            internal_arr[element_counter + 1] <= temp_val;
                            
                            temp_sum = digit_sum[element_counter];
                            digit_sum[element_counter] <= digit_sum[element_counter + 1];
                            digit_sum[element_counter + 1] <= temp_sum;
                        end
                        element_counter <= element_counter + 4'd1;
                    end else begin
                        element_counter <= 4'd0;
                        if (pass_counter < 6) begin
                            pass_counter <= pass_counter + 4'd1;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Output the sorted array
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= internal_arr[i];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule