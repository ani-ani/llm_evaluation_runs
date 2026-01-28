module SimplifiedNonRepeatedElementsSummationModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SORTING = 2'd1;
    localparam [1:0] SUMMING = 2'd2;
    localparam [1:0] FINISHED = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] sorted_arr [0:7];
    reg [3:0] sort_pass;      // 0 to 7
    reg [3:0] sort_index;     // 0 to 6 for inner loop
    reg [2:0] sum_index;      // 0 to 7 for summation
    reg [15:0] sum_temp;
    reg [7:0] last_value;
    reg [7:0] swap_temp;
    
    // Loop counter (for loops that compile to hardware)
    integer i;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SORTING;
                else
                    next_state = IDLE;
            end
            SORTING: begin
                if (sort_pass == 7'd7 && sort_index == 4'd7)
                    next_state = SUMMING;
                else
                    next_state = SORTING;
            end
            SUMMING: begin
                if (sum_index == 3'd7)
                    next_state = FINISHED;
                else
                    next_state = SUMMING;
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            sort_pass <= 4'd0;
            sort_index <= 4'd0;
            sum_index <= 3'd0;
            sum_temp <= 16'd0;
            last_value <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                sorted_arr[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    sum_temp <= 16'd0;
                    sum_index <= 3'd0;
                    sort_pass <= 4'd0;
                    sort_index <= 4'd0;
                    
                    // Load input array into working register
                    if (start) begin
                        sorted_arr[0] <= arr_0;
                        sorted_arr[1] <= arr_1;
                        sorted_arr[2] <= arr_2;
                        sorted_arr[3] <= arr_3;
                        sorted_arr[4] <= arr_4;
                        sorted_arr[5] <= arr_5;
                        sorted_arr[6] <= arr_6;
                        sorted_arr[7] <= arr_7;
                    end
                end
                
                SORTING: begin
                    // Bubble sort logic
                    if (sort_pass < 7'd7) begin
                        if (sort_index < 4'd7) begin
                            // Compare and swap adjacent elements
                            if (sorted_arr[sort_index] > sorted_arr[sort_index + 4'd1]) begin
                                swap_temp <= sorted_arr[sort_index];
                                sorted_arr[sort_index] <= sorted_arr[sort_index + 4'd1];
                                sorted_arr[sort_index + 4'd1] <= swap_temp;
                            end
                            sort_index <= sort_index + 4'd1;
                        end else begin
                            // End of pass
                            sort_pass <= sort_pass + 4'd1;
                            sort_index <= 4'd0;
                        end
                    end
                end
                
                SUMMING: begin
                    // Sum only non-repeated elements
                    if (sum_index == 3'd0) begin
                        // Start with first element
                        last_value <= sorted_arr[0];
                        sum_temp <= {8'd0, sorted_arr[0]};
                        sum_index <= 3'd1;
                    end else if (sum_index < 3'd7) begin
                        // Check if current element is different from previous
                        if (sorted_arr[sum_index] != last_value) begin
                            sum_temp <= sum_temp + {8'd0, sorted_arr[sum_index]};
                            last_value <= sorted_arr[sum_index];
                        end
                        sum_index <= sum_index + 3'd1;
                    end else begin
                        // Process last element (index 7)
                        if (sorted_arr[7] != last_value) begin
                            sum_temp <= sum_temp + {8'd0, sorted_arr[7]};
                        end
                        sum_index <= sum_index + 3'd1;
                    end
                end
                
                FINISHED: begin
                    result <= sum_temp;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 16'd0;
                    sum_temp <= 16'd0;
                end
            endcase
        end
    end

endmodule