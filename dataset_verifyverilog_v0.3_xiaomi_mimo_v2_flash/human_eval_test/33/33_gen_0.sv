module sort_third(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

// State definitions
localparam [2:0] IDLE     = 3'd0;
localparam [2:0] LOAD     = 3'd1;
localparam [2:0] EXTRACT  = 3'd2;
localparam [2:0] SORT     = 3'd3;
localparam [2:0] RESTORE  = 3'd4;
localparam [2:0] FINISH   = 3'd5;

reg [2:0] state, next_state;
reg [7:0] temp_arr [0:7];        // Buffer for input array
reg [7:0] special[0:2];          // Extracted elements at indices 0, 3, 6
reg [1:0] sort_idx;              // Index for bubble sort pass
reg [1:0] pass_count;            // Number of bubble sort passes completed
reg [2:0] loop_counter;          // Generic loop counter

integer i;

// FSM: State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result[0] <= 8'd0; result[1] <= 8'd0; result[2] <= 8'd0; result[3] <= 8'd0;
        result[4] <= 8'd0; result[5] <= 8'd0; result[6] <= 8'd0; result[7] <= 8'd0;
        done <= 1'b0;
        temp_arr[0] <= 8'd0; temp_arr[1] <= 8'd0; temp_arr[2] <= 8'd0; temp_arr[3] <= 8'd0;
        temp_arr[4] <= 8'd0; temp_arr[5] <= 8'd0; temp_arr[6] <= 8'd0; temp_arr[7] <= 8'd0;
        special[0] <= 8'd0; special[1] <= 8'd0; special[2] <= 8'd0;
        sort_idx <= 2'd0;
        pass_count <= 2'd0;
        loop_counter <= 3'd0;
    end else begin
        state <= next_state;
        
        // Default done behavior
        if (state != FINISH) begin
            done <= 1'b0;
        end
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                sort_idx <= 2'd0;
                pass_count <= 2'd0;
                loop_counter <= 3'd0;
            end
            
            LOAD: begin
                // Capture input array
                temp_arr[0] <= arr[0]; temp_arr[1] <= arr[1]; temp_arr[2] <= arr[2]; temp_arr[3] <= arr[3];
                temp_arr[4] <= arr[4]; temp_arr[5] <= arr[5]; temp_arr[6] <= arr[6]; temp_arr[7] <= arr[7];
            end
            
            EXTRACT: begin
                // Extract elements at indices 0, 3, 6
                special[0] <= temp_arr[0];
                special[1] <= temp_arr[3];
                special[2] <= temp_arr[6];
            end
            
            SORT: begin
                // Bubble sort on 3 elements: compare adjacent pairs
                case (sort_idx)
                    2'd0: begin
                        // Compare special[0] and special[1]
                        if (special[0] > special[1]) begin
                            special[0] <= special[1];
                            special[1] <= special[0];
                        end
                        sort_idx <= 2'd1;
                    end
                    2'd1: begin
                        // Compare special[1] and special[2]
                        if (special[1] > special[2]) begin
                            special[1] <= special[2];
                            special[2] <= special[1];
                        end
                        sort_idx <= 2'd2;
                    end
                    2'd2: begin
                        // Reset for next pass
                        sort_idx <= 2'd0;
                        pass_count <= pass_count + 2'd1;
                    end
                endcase
            end
            
            RESTORE: begin
                // Place sorted elements back at indices 0, 3, 6
                result[0] <= special[0];
                result[3] <= special[1];
                result[6] <= special[2];
                // Copy unchanged elements
                result[1] <= temp_arr[1];
                result[2] <= temp_arr[2];
                result[4] <= temp_arr[4];
                result[5] <= temp_arr[5];
                result[7] <= temp_arr[7];
            end
            
            FINISH: begin
                done <= 1'b1;
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
                next_state = LOAD;
            end
        end
        
        LOAD: begin
            next_state = EXTRACT;
        end
        
        EXTRACT: begin
            next_state = SORT;
        end
        
        SORT: begin
            // Complete 2 passes of bubble sort for 3 elements
            if (pass_count >= 2'd2 && sort_idx == 2'd2) begin
                next_state = RESTORE;
            end
        end
        
        RESTORE: begin
            next_state = FINISH;
        end
        
        FINISH: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule