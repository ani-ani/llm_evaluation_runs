module min_heterogeneous(
    input clk,
    input rst_n,
    input start,
    input [2:0] count,
    input [7:0] data_in,
    input load,
    output reg [7:0] min_result,
    output reg done,
    output reg error
);

    // Internal array storage
    reg [7:0] data_array [0:7];
    
    // State encoding
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam PROCESSING = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] state, next_state;
    reg [2:0] index;          // Index for loading and processing
    reg [7:0] current_min;    // Current minimum value
    reg found_valid;          // Flag to indicate at least one valid integer found
    
    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'b0;
            current_min <= 8'hFF;
            found_valid <= 1'b0;
            min_result <= 8'b0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        index <= 3'b0;
                        current_min <= 8'hFF;
                        found_valid <= 1'b0;
                        done <= 1'b0;
                        error <= 1'b0;
                    end
                end
                
                LOAD: begin
                    if (load && index < count) begin
                        data_array[index] <= data_in;
                        index <= index + 1'b1;
                    end
                    if (load && index == count - 1'b1) begin
                        index <= 3'b0;
                    end
                end
                
                PROCESSING: begin
                    if (index < count) begin
                        // Check if element is valid (less than 255)
                        if (data_array[index] < 8'hFF) begin
                            if (found_valid) begin
                                if (data_array[index] < current_min)
                                    current_min <= data_array[index];
                            end else begin
                                current_min <= data_array[index];
                                found_valid <= 1'b1;
                            end
                        end
                        index <= index + 1'b1;
                    end
                end
                
                DONE: begin
                    if (found_valid) begin
                        min_result <= current_min;
                        error <= 1'b0;
                    end else begin
                        min_result <= 8'hFF;
                        error <= 1'b1;
                    end
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
                if (start)
                    next_state = LOAD;
            end
            
            LOAD: begin
                // Wait until all count elements are loaded
                // Transitions when load is high and index reaches count
                if (load && (index == count - 1'b1))
                    next_state = PROCESSING;
                // Handle case where count might be 0 or 1
                else if (load && count == 3'd1)
                    next_state = PROCESSING;
            end
            
            PROCESSING: begin
                // Wait until all elements are processed
                if (index == count)
                    next_state = DONE;
            end
            
            DONE: begin
                // Return to IDLE (or stay, depending on system design)
                // For this implementation, go back to IDLE when start is low
                if (!start)
                    next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule}