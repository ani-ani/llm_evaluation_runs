module sort_numbers(
    input clk,
    input rst_n,
    input start,
    input [3:0] numbers [0:7],
    input [2:0] valid_count,
    output reg [3:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SORTING = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Internal registers
    reg [3:0] temp_array [0:7];
    reg [2:0] pass_count;       // Outer pass counter
    reg [2:0] index_count;      // Inner index counter
    reg [2:0] max_passes;       // Calculated from valid_count
    reg [2:0] max_index;        // Calculated from valid_count and pass
    
    // Counter for cycle limit (prevent infinite loops)
    reg [6:0] cycle_counter;    // Up to 128 cycles
    
    integer i;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_counter <= 7'd0;
            pass_count <= 3'd0;
            index_count <= 3'd0;
            max_passes <= 3'd0;
            max_index <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                temp_array[i] <= 4'd0;
                result[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 7'd0;
                    pass_count <= 3'd0;
                    index_count <= 3'd0;
                    
                    if (start) begin
                        // Initialize temp_array from input
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < valid_count)
                                temp_array[i] <= numbers[i];
                            else
                                temp_array[i] <= 4'd0;
                        end
                        
                        // Calculate max passes: valid_count - 1 (or 0 if <= 1)
                        if (valid_count > 3'd1)
                            max_passes <= valid_count - 3'd1;
                        else
                            max_passes <= 3'd0;
                    end
                end
                
                SORTING: begin
                    cycle_counter <= cycle_counter + 7'd1;
                    
                    if (pass_count < max_passes) begin
                        // Calculate max_index for current pass: valid_count - pass_count - 1
                        if (valid_count > pass_count + 3'd1)
                            max_index <= valid_count - pass_count - 3'd1;
                        else
                            max_index <= 3'd0;
                        
                        if (index_count < max_index) begin
                            // Compare and swap
                            if (temp_array[index_count] > temp_array[index_count + 3'd1]) begin
                                // Swap
                                temp_array[index_count] <= temp_array[index_count + 3'd1];
                                temp_array[index_count + 3'd1] <= temp_array[index_count];
                            end
                            index_count <= index_count + 3'd1;
                        end else begin
                            // End of inner loop
                            index_count <= 3'd0;
                            pass_count <= pass_count + 3'd1;
                        end
                    end else begin
                        // All passes complete
                        for (i = 0; i < 8; i = i + 1) begin
                            result[i] <= temp_array[i];
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
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
                    if (valid_count <= 3'd1) begin
                        // No sorting needed (0 or 1 element)
                        next_state = DONE;
                    end else begin
                        next_state = SORTING;
                    end
                end
            end
            
            SORTING: begin
                // Check if sorting complete
                if (pass_count >= max_passes) begin
                    next_state = DONE;
                end
                // Safety: prevent infinite loops
                else if (cycle_counter >= 7'd100) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                // Return to IDLE
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule