module find_closest_elements (
    input clk,
    input rst_n,
    input start,
    input [15:0] arr_0,
    input [15:0] arr_1,
    input [15:0] arr_2,
    input [15:0] arr_3,
    input [15:0] arr_4,
    input [15:0] arr_5,
    output reg [15:0] min_val,
    output reg [15:0] max_val,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] LOAD       = 4'd1;
    localparam [3:0] SORT_0     = 4'd2;
    localparam [3:0] SORT_1     = 4'd3;
    localparam [3:0] SORT_2     = 4'd4;
    localparam [3:0] SORT_3     = 4'd5;
    localparam [3:0] SORT_4     = 4'd6;
    localparam [3:0] DIFF_CALC  = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    reg [3:0] state, next_state;
    
    // Internal registers for sorted array
    reg [15:0] sorted [0:5];
    
    // Intermediate registers for bubble sort comparisons
    reg [15:0] temp_a, temp_b;
    reg swap;
    
    // Variables for difference calculation
    reg [15:0] current_diff;
    reg [15:0] best_diff;
    reg [15:0] best_min;
    reg [15:0] best_max;
    integer idx;
    integer i;

    // State transition and register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_val <= 16'd0;
            max_val <= 16'd0;
            done <= 1'b0;
            for (i = 0; i < 6; i = i + 1) begin
                sorted[i] <= 16'd0;
            end
            temp_a <= 16'd0;
            temp_b <= 16'd0;
            swap <= 1'b0;
            current_diff <= 16'd0;
            best_diff <= 16'hFFFF;
            best_min <= 16'd0;
            best_max <= 16'd0;
            idx <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    best_diff <= 16'hFFFF;
                end
                
                LOAD: begin
                    sorted[0] <= arr_0;
                    sorted[1] <= arr_1;
                    sorted[2] <= arr_2;
                    sorted[3] <= arr_3;
                    sorted[4] <= arr_4;
                    sorted[5] <= arr_5;
                    idx <= 0;
                end
                
                SORT_0: begin
                    // Pass 1: (0,1), (1,2), (2,3), (3,4), (4,5)
                    if (sorted[0] > sorted[1]) begin
                        temp_a <= sorted[1];
                        sorted[0] <= sorted[0];
                        sorted[1] <= temp_a;
                    end
                    if (sorted[1] > sorted[2]) begin
                        temp_a <= sorted[2];
                        sorted[1] <= sorted[1];
                        sorted[2] <= temp_a;
                    end
                    if (sorted[2] > sorted[3]) begin
                        temp_a <= sorted[3];
                        sorted[2] <= sorted[2];
                        sorted[3] <= temp_a;
                    end
                    if (sorted[3] > sorted[4]) begin
                        temp_a <= sorted[4];
                        sorted[3] <= sorted[3];
                        sorted[4] <= temp_a;
                    end
                    if (sorted[4] > sorted[5]) begin
                        temp_a <= sorted[5];
                        sorted[4] <= sorted[4];
                        sorted[5] <= temp_a;
                    end
                end
                
                SORT_1: begin
                    // Pass 2: (0,1), (1,2), (2,3), (3,4)
                    if (sorted[0] > sorted[1]) begin
                        temp_a <= sorted[1];
                        sorted[0] <= sorted[0];
                        sorted[1] <= temp_a;
                    end
                    if (sorted[1] > sorted[2]) begin
                        temp_a <= sorted[2];
                        sorted[1] <= sorted[1];
                        sorted[2] <= temp_a;
                    end
                    if (sorted[2] > sorted[3]) begin
                        temp_a <= sorted[3];
                        sorted[2] <= sorted[2];
                        sorted[3] <= temp_a;
                    end
                    if (sorted[3] > sorted[4]) begin
                        temp_a <= sorted[4];
                        sorted[3] <= sorted[3];
                        sorted[4] <= temp_a;
                    end
                end
                
                SORT_2: begin
                    // Pass 3: (0,1), (1,2), (2,3)
                    if (sorted[0] > sorted[1]) begin
                        temp_a <= sorted[1];
                        sorted[0] <= sorted[0];
                        sorted[1] <= temp_a;
                    end
                    if (sorted[1] > sorted[2]) begin
                        temp_a <= sorted[2];
                        sorted[1] <= sorted[1];
                        sorted[2] <= temp_a;
                    end
                    if (sorted[2] > sorted[3]) begin
                        temp_a <= sorted[3];
                        sorted[2] <= sorted[2];
                        sorted[3] <= temp_a;
                    end
                end
                
                SORT_3: begin
                    // Pass 4: (0,1), (1,2)
                    if (sorted[0] > sorted[1]) begin
                        temp_a <= sorted[1];
                        sorted[0] <= sorted[0];
                        sorted[1] <= temp_a;
                    end
                    if (sorted[1] > sorted[2]) begin
                        temp_a <= sorted[2];
                        sorted[1] <= sorted[1];
                        sorted[2] <= temp_a;
                    end
                end
                
                SORT_4: begin
                    // Pass 5: (0,1)
                    if (sorted[0] > sorted[1]) begin
                        temp_a <= sorted[1];
                        sorted[0] <= sorted[0];
                        sorted[1] <= temp_a;
                    end
                end
                
                DIFF_CALC: begin
                    // Calculate differences between adjacent sorted elements
                    // Index 0 to 4
                    case (idx)
                        0: current_diff <= sorted[1] - sorted[0];
                        1: current_diff <= sorted[2] - sorted[1];
                        2: current_diff <= sorted[3] - sorted[2];
                        3: current_diff <= sorted[4] - sorted[3];
                        4: current_diff <= sorted[5] - sorted[4];
                        default: current_diff <= 16'd0;
                    endcase
                    
                    // Compare and update best
                    if (current_diff < best_diff) begin
                        best_diff <= current_diff;
                        best_min <= (idx == 0) ? sorted[0] : (idx == 1) ? sorted[1] : (idx == 2) ? sorted[2] : (idx == 3) ? sorted[3] : sorted[4];
                        best_max <= (idx == 0) ? sorted[1] : (idx == 1) ? sorted[2] : (idx == 2) ? sorted[3] : (idx == 3) ? sorted[4] : sorted[5];
                    end
                    idx <= idx + 1;
                end
                
                DONE_STATE: begin
                    min_val <= best_min;
                    max_val <= best_max;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            
            LOAD: next_state = SORT_0;
            
            SORT_0: next_state = SORT_1;
            
            SORT_1: next_state = SORT_2;
            
            SORT_2: next_state = SORT_3;
            
            SORT_3: next_state = SORT_4;
            
            SORT_4: next_state = DIFF_CALC;
            
            DIFF_CALC: begin
                if (idx > 4) next_state = DONE_STATE;
                else next_state = DIFF_CALC;
            end
            
            DONE_STATE: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

endmodule