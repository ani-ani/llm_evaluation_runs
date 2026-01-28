module MinimalPileCount(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr[0:15],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] SORTING     = 3'd1;
    localparam [2:0] SORTING2    = 3'd2;
    localparam [2:0] ALLOCATING  = 3'd3;
    localparam [2:0] FINISHING   = 3'd4;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] sorted_arr[0:15];
    reg [7:0] pile_heights[0:15];
    reg [3:0] i, j, box_idx;
    reg [3:0] pile_count;
    reg [7:0] cycle_counter;
    reg [7:0] temp_val;
    
    // Max cycles for timeout protection
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // State transition logic (combinational)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && len == 4'd0) begin
                    next_state = FINISHING;
                end else if (start) begin
                    next_state = SORTING;
                end else begin
                    next_state = IDLE;
                end
            end
            
            SORTING: begin
                if (i < len - 4'd1) begin
                    next_state = SORTING2;
                end else begin
                    next_state = ALLOCATING;
                end
            end
            
            SORTING2: begin
                if (j > 4'd0 && sorted_arr[j] < sorted_arr[j-4'd1]) begin
                    next_state = SORTING2;
                end else begin
                    next_state = SORTING;
                end
            end
            
            ALLOCATING: begin
                if (box_idx < len) begin
                    next_state = ALLOCATING;
                end else begin
                    next_state = FINISHING;
                end
            end
            
            FINISHING: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_counter <= 8'd0;
            pile_count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            box_idx <= 4'd0;
            temp_val <= 8'd0;
            
            // Initialize arrays
            sorted_arr[0] <= 8'd0; sorted_arr[1] <= 8'd0;
            sorted_arr[2] <= 8'd0; sorted_arr[3] <= 8'd0;
            sorted_arr[4] <= 8'd0; sorted_arr[5] <= 8'd0;
            sorted_arr[6] <= 8'd0; sorted_arr[7] <= 8'd0;
            sorted_arr[8] <= 8'd0; sorted_arr[9] <= 8'd0;
            sorted_arr[10] <= 8'd0; sorted_arr[11] <= 8'd0;
            sorted_arr[12] <= 8'd0; sorted_arr[13] <= 8'd0;
            sorted_arr[14] <= 8'd0; sorted_arr[15] <= 8'd0;
            
            pile_heights[0] <= 8'd0; pile_heights[1] <= 8'd0;
            pile_heights[2] <= 8'd0; pile_heights[3] <= 8'd0;
            pile_heights[4] <= 8'd0; pile_heights[5] <= 8'd0;
            pile_heights[6] <= 8'd0; pile_heights[7] <= 8'd0;
            pile_heights[8] <= 8'd0; pile_heights[9] <= 8'd0;
            pile_heights[10] <= 8'd0; pile_heights[11] <= 8'd0;
            pile_heights[12] <= 8'd0; pile_heights[13] <= 8'd0;
            pile_heights[14] <= 8'd0; pile_heights[15] <= 8'd0;
            
        end else begin
            state <= next_state;
            done <= 1'b0;
            cycle_counter <= cycle_counter + 8'd1;
            
            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    if (start && len == 4'd0) begin
                        result <= 8'd0;
                        done <= 1'b1;
                    end else if (start) begin
                        // Copy input to sorted array
                        sorted_arr[0] <= arr[0];
                        sorted_arr[1] <= arr[1];
                        sorted_arr[2] <= arr[2];
                        sorted_arr[3] <= arr[3];
                        sorted_arr[4] <= arr[4];
                        sorted_arr[5] <= arr[5];
                        sorted_arr[6] <= arr[6];
                        sorted_arr[7] <= arr[7];
                        sorted_arr[8] <= arr[8];
                        sorted_arr[9] <= arr[9];
                        sorted_arr[10] <= arr[10];
                        sorted_arr[11] <= arr[11];
                        sorted_arr[12] <= arr[12];
                        sorted_arr[13] <= arr[13];
                        sorted_arr[14] <= arr[14];
                        sorted_arr[15] <= arr[15];
                        
                        // Reset state variables
                        pile_count <= 4'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                        box_idx <= 4'd0;
                    end
                end
                
                SORTING: begin
                    if (i < len - 4'd1) begin
                        i <= i + 4'd1;
                        j <= i + 4'd1;
                    end
                end
                
                SORTING2: begin
                    if (j > 4'd0 && sorted_arr[j] < sorted_arr[j-4'd1]) begin
                        temp_val <= sorted_arr[j-4'd1];
                        sorted_arr[j-4'd1] <= sorted_arr[j];
                        sorted_arr[j] <= temp_val;
                        j <= j - 4'd1;
                    end else begin
                        // Continue outer loop
                    end
                end
                
                ALLOCATING: begin
                    if (box_idx < len) begin
                        // Find first pile where pile_heights <= current box
                        if (pile_heights[0] <= sorted_arr[box_idx]) begin
                            pile_heights[0] <= pile_heights[0] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[1] <= sorted_arr[box_idx]) begin
                            pile_heights[1] <= pile_heights[1] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[2] <= sorted_arr[box_idx]) begin
                            pile_heights[2] <= pile_heights[2] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[3] <= sorted_arr[box_idx]) begin
                            pile_heights[3] <= pile_heights[3] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[4] <= sorted_arr[box_idx]) begin
                            pile_heights[4] <= pile_heights[4] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[5] <= sorted_arr[box_idx]) begin
                            pile_heights[5] <= pile_heights[5] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[6] <= sorted_arr[box_idx]) begin
                            pile_heights[6] <= pile_heights[6] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[7] <= sorted_arr[box_idx]) begin
                            pile_heights[7] <= pile_heights[7] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[8] <= sorted_arr[box_idx]) begin
                            pile_heights[8] <= pile_heights[8] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[9] <= sorted_arr[box_idx]) begin
                            pile_heights[9] <= pile_heights[9] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[10] <= sorted_arr[box_idx]) begin
                            pile_heights[10] <= pile_heights[10] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[11] <= sorted_arr[box_idx]) begin
                            pile_heights[11] <= pile_heights[11] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[12] <= sorted_arr[box_idx]) begin
                            pile_heights[12] <= pile_heights[12] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[13] <= sorted_arr[box_idx]) begin
                            pile_heights[13] <= pile_heights[13] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[14] <= sorted_arr[box_idx]) begin
                            pile_heights[14] <= pile_heights[14] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else if (pile_heights[15] <= sorted_arr[box_idx]) begin
                            pile_heights[15] <= pile_heights[15] + 8'd1;
                            box_idx <= box_idx + 4'd1;
                        end else begin
                            // Create new pile
                            if (pile_count < 4'd16) begin
                                pile_heights[pile_count] <= 8'd1;
                                pile_count <= pile_count + 4'd1;
                            end
                            box_idx <= box_idx + 4'd1;
                        end
                    end
                end
                
                FINISHING: begin
                    result <= {4'd0, pile_count};
                    done <= 1'b1;
                end
            endcase
            
            // Timeout protection
            if (cycle_counter >= MAX_CYCLES) begin
                state <= FINISHING;
                result <= 8'd0;
                done <= 1'b1;
            end
        end
    end
endmodule