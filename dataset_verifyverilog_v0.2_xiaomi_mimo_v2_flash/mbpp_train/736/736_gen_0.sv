module left_insertion(
    input clk,
    input rst_n,
    input start,
    input [7:0] value,
    input [2:0] array_size,
    input [7:0] array_data [0:7],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        SEARCH  = 2'b01,
        UPDATE  = 2'b10,
        DONE    = 2'b11
    } state_t;
    
    state_t current_state, next_state;
    
    // Registers for binary search
    reg [3:0] low, next_low;
    reg [3:0] high, next_high;
    reg [3:0] mid;
    
    // Combinational logic for mid calculation
    // mid = (low + high) >> 1
    wire [4:0] sum = {1'b0, low} + {1'b0, high};
    
    always @(*) begin
        mid = sum[4:1]; // div by 2
    end
    
    // State transition logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_low = low;
        next_high = high;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                    next_low = 4'b0000;
                    next_high = {1'b0, array_size}; // extend to 4 bits
                end
            end
            
            SEARCH: begin
                next_state = UPDATE;
            end
            
            UPDATE: begin
                if (value > array_data[mid[2:0]]) begin
                    next_low = mid + 1;
                    next_high = high;
                end else begin
                    next_low = low;
                    next_high = mid;
                end
                
                // Check termination condition
                if (next_low >= next_high) begin
                    next_state = DONE;
                end else begin
                    next_state = SEARCH;
                end
            end
            
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            low <= 4'b0000;
            high <= 4'b0000;
            result <= 4'b0000;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            low <= next_low;
            high <= next_high;
            
            if (current_state == DONE) begin
                result <= low;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule