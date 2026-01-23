module max_val_heterogeneous (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] num_elements,
    input wire [7:0] array_data [0:7],
    output reg [7:0] max_int_result,
    output reg done,
    output reg valid
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SCAN = 2'b01;
    localparam UPDATE_MAX = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state, next_state;
    reg [2:0] index, next_index;
    reg [7:0] max_val, next_max_val;
    reg found_integer, next_found_integer;
    reg [7:0] current_element;

    // Sequential logic for state and data registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            index <= 3'b0;
            max_val <= 8'h00;
            found_integer <= 1'b0;
        end else begin
            current_state <= next_state;
            index <= next_index;
            max_val <= next_max_val;
            found_integer <= next_found_integer;
        end
    end

    // Combinational logic for next state and outputs
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_index = index;
        next_max_val = max_val;
        next_found_integer = found_integer;
        
        done = 1'b0;
        valid = 1'b0;
        max_int_result = 8'h00;
        
        // Index bounds checking
        // Ensure we don't access out of bounds even if num_elements is large
        if (index < 3'd8) begin
            current_element = array_data[index];
        end else begin
            current_element = 8'h00;
        end

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SCAN;
                    next_index = 3'b0;
                    next_max_val = 8'h00;
                    next_found_integer = 1'b0;
                end
            end

            SCAN: begin
                // Check if we have processed all elements
                if (index >= num_elements) begin
                    next_state = DONE;
                end else begin
                    // Process current element
                    // 0x00 is string marker, 0x01-0xFF are integers
                    if (current_element != 8'h00) begin
                        next_state = UPDATE_MAX;
                    end else begin
                        // String marker, skip update, move to next
                        next_index = index + 1'b1;
                        next_state = SCAN;
                    end
                end
            end

            UPDATE_MAX: begin
                // Compare current element with current max
                // Note: current_element is guaranteed to be != 0x00 here
                if (current_element > max_val) begin
                    next_max_val = current_element;
                    next_found_integer = 1'b1;
                end else if (!found_integer) begin
                    // If this is the first integer found (and max_val is still 0x00)
                    // But wait, if current_element > max_val was false and max_val is 0x00,
                    // then current_element must be 0x00 which contradicts SCAN condition.
                    // However, to be safe and handle the first valid integer correctly:
                    if (max_val == 8'h00) begin
                        next_max_val = current_element;
                        next_found_integer = 1'b1;
                    end
                end
                
                next_index = index + 1'b1;
                next_state = SCAN;
            end

            DONE: begin
                done = 1'b1;
                if (found_integer) begin
                    valid = 1'b1;
                    max_int_result = max_val;
                end else begin
                    valid = 1'b0;
                    max_int_result = 8'h00;
                end
                // Stay in DONE until reset
            end

            default: begin
                next_state = IDLE;
                next_index = 3'b0;
                next_max_val = 8'h00;
                next_found_integer = 1'b0;
            end
        endcase
    end

endmodule
