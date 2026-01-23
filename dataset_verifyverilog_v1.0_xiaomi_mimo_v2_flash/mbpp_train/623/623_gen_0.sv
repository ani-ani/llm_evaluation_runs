module power_calculator(
    input clk,
    input rst_n,
    input start,
    input [4:0] exponent,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    output reg [31:0] result_0, result_1, result_2, result_3, result_4, result_5, result_6, result_7,
    output reg done
);

    // Internal parameters
    localparam [3:0] ARRAY_SIZE = 4'd8;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] LOAD_ELEMENT = 3'd1;
    localparam [2:0] COMPUTE_POWER = 3'd2;
    localparam [2:0] STORE_RESULT = 3'd3;
    localparam [2:0] FINISH       = 3'd4;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] array_index;           // Index for current element (0-7)
    reg [4:0] exp_counter;           // Counter for exponentiation loops
    reg [31:0] current_element;      // Current input element (extended to 32-bit)
    reg [31:0] current_result;       // Result being computed
    reg [31:0] result_buffer [0:7];  // Result buffer array
    reg [7:0] cycle_count;           // Timeout prevention
    reg computation_done;            // Flag for computation completion
    
    // Input mapping
    wire [7:0] arr [0:7];
    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;
    assign arr[7] = arr_7;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_ELEMENT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD_ELEMENT: begin
                if (exponent == 5'd0) begin
                    // Exponent 0: result is 1 immediately
                    next_state = STORE_RESULT;
                end else if (exponent == 5'd1) begin
                    // Exponent 1: result is input immediately
                    next_state = STORE_RESULT;
                end else begin
                    next_state = COMPUTE_POWER;
                end
            end
            
            COMPUTE_POWER: begin
                if (exp_counter >= exponent) begin
                    next_state = STORE_RESULT;
                end else begin
                    next_state = COMPUTE_POWER;
                end
            end
            
            STORE_RESULT: begin
                if (array_index < (ARRAY_SIZE - 3'd1)) begin
                    next_state = LOAD_ELEMENT;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            array_index <= 3'd0;
            exp_counter <= 5'd0;
            current_element <= 32'd0;
            current_result <= 32'd0;
            cycle_count <= 8'd0;
            computation_done <= 1'b0;
            done <= 1'b0;
            result_0 <= 32'd0;
            result_1 <= 32'd0;
            result_2 <= 32'd0;
            result_3 <= 32'd0;
            result_4 <= 32'd0;
            result_5 <= 32'd0;
            result_6 <= 32'd0;
            result_7 <= 32'd0;
            result_buffer[0] <= 32'd0;
            result_buffer[1] <= 32'd0;
            result_buffer[2] <= 32'd0;
            result_buffer[3] <= 32'd0;
            result_buffer[4] <= 32'd0;
            result_buffer[5] <= 32'd0;
            result_buffer[6] <= 32'd0;
            result_buffer[7] <= 32'd0;
        end else begin
            // State machine
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        array_index <= 3'd0;
                        cycle_count <= 8'd0;
                    end
                end
                
                LOAD_ELEMENT: begin
                    // Load current element from input array
                    current_element <= {24'd0, arr[array_index]};
                    exp_counter <= 5'd0;
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Handle special cases
                    if (exponent == 5'd0) begin
                        current_result <= 32'd1;  // Any^0 = 1
                    end else if (exponent == 5'd1) begin
                        current_result <= {24'd0, arr[array_index]};  // Any^1 = itself
                    end else begin
                        current_result <= 32'd1;  // Initialize for multiplication
                    end
                end
                
                COMPUTE_POWER: begin
                    // Iterative multiplication: current_result = current_result * current_element
                    current_result <= current_result * current_element;
                    exp_counter <= exp_counter + 5'd1;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                STORE_RESULT: begin
                    // Store result in buffer
                    result_buffer[array_index] <= current_result;
                    array_index <= array_index + 3'd1;
                end
                
                FINISH: begin
                    // Transfer buffer to outputs and assert done
                    result_0 <= result_buffer[0];
                    result_1 <= result_buffer[1];
                    result_2 <= result_buffer[2];
                    result_3 <= result_buffer[3];
                    result_4 <= result_buffer[4];
                    result_5 <= result_buffer[5];
                    result_6 <= result_buffer[6];
                    result_7 <= result_buffer[7];
                    done <= 1'b1;
                end
                
                default: begin
                    // Should not reach here
                    state <= IDLE;
                end
            endcase
            
            // Timeout prevention - if cycle count exceeds max, force to FINISH
            if (cycle_count >= MAX_CYCLES && state != FINISH && state != IDLE) begin
                state <= STORE_RESULT;
            end
        end
    end

endmodule