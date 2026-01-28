module digit_frequency_validator (
    input clk,
    input rst_n,
    input start,
    input [15:0] num_in,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] EXTRACT = 2'd1;
    localparam [1:0] VALIDATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // State registers
    reg [1:0] state, next_state;
    
    // Counter for cycles
    reg [4:0] cycle_count;
    localparam [4:0] EXTRACT_CYCLES = 5'd16;
    localparam [4:0] VALIDATE_CYCLES = 5'd10;
    localparam [4:0] MAX_CYCLES = 5'd20;
    
    // Counter for digit validation
    reg [3:0] digit_check;
    
    // Frequency array for digits 0-9 (each 4-bit counter)
    reg [3:0] freq [0:9];
    
    // Current digit being processed
    reg [3:0] current_digit;
    
    // Valid flag for validation
    reg is_valid;
    
    // Temporary register for num_in processing
    reg [15:0] temp_num;
    
    integer i;

    // State transition and synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 5'd0;
            digit_check <= 4'd0;
            is_valid <= 1'b0;
            temp_num <= 16'd0;
            current_digit <= 4'd0;
            // Initialize frequency array
            for (i = 0; i < 10; i = i + 1) begin
                freq[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 5'd0;
                    digit_check <= 4'd0;
                    is_valid <= 1'b0;
                    temp_num <= 16'd0;
                    current_digit <= 4'd0;
                    // Initialize frequency array to 0
                    for (i = 0; i < 10; i = i + 1) begin
                        freq[i] <= 4'd0;
                    end
                    
                    if (start) begin
                        temp_num <= num_in;
                    end
                end
                
                EXTRACT: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Extract LSB (4 bits) and increment frequency
                    current_digit <= temp_num[3:0];
                    
                    // Check if digit is valid (0-9) before incrementing
                    if (temp_num[3:0] <= 4'd9) begin
                        freq[temp_num[3:0]] <= freq[temp_num[3:0]] + 4'd1;
                    end
                    
                    // Shift right by 4 bits (next nibble)
                    temp_num <= {4'd0, temp_num[15:4]};
                    
                    // After 16 cycles, go to validation
                end
                
                VALIDATE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Check if frequency of digit_check is <= digit_check
                    if (freq[digit_check] > digit_check) begin
                        is_valid <= 1'b0;
                    end else if (digit_check == 4'd9) begin
                        // Last digit checked, all passed so far
                        is_valid <= 1'b1;
                    end
                    
                    digit_check <= digit_check + 4'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= is_valid;
                    // Clear cycle_count for next operation
                    cycle_count <= 5'd0;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
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
                    next_state = EXTRACT;
                end
            end
            
            EXTRACT: begin
                if (cycle_count >= EXTRACT_CYCLES - 5'd1) begin
                    next_state = VALIDATE;
                end
            end
            
            VALIDATE: begin
                if (cycle_count >= (EXTRACT_CYCLES + VALIDATE_CYCLES - 5'd1)) begin
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

endmodule