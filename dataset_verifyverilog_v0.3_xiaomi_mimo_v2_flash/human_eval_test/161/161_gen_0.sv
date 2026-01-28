module string_transform (
    input clk,
    input rst_n,
    input start,
    input [127:0] data_in,
    output reg [127:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_LETTERS = 3'd1;
    localparam [2:0] TRANSFORM = 3'd2;
    localparam [2:0] REVERSE = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // Internal registers and signals
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] counter;          // 0 to 15 for scanning/processing
    reg has_letter;
    reg [127:0] result_reg;     // Registered result
    reg [7:0] current_byte;     // Current byte being processed
    reg [7:0] temp_byte;        // Temporary storage for transformed byte
    reg [7:0] current_char;     // Character during transformation/reversal
    
    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            has_letter <= 1'b0;
            result_reg <= 128'd0;
            done <= 1'b0;
            current_byte <= 8'd0;
            temp_byte <= 8'd0;
            current_char <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    if (start) begin
                        has_letter <= 1'b0;
                    end
                end
                
                CHECK_LETTERS: begin
                    // Extract byte from data_in[8*counter +: 8]
                    current_byte <= data_in[8*counter +: 8];
                    
                    // Check if byte is letter (A-Z or a-z)
                    // A=65(0x41), Z=90(0x5A), a=97(0x61), z=122(0x7A)
                    if ((current_byte >= 8'd65 && current_byte <= 8'd90) || 
                        (current_byte >= 8'd97 && current_byte <= 8'd122)) begin
                        has_letter <= 1'b1;
                    end
                    
                    if (counter < 4'd15) begin
                        counter <= counter + 4'd1;
                    end
                end
                
                TRANSFORM: begin
                    // Flip case by XORing with 8'h20 (bit 5)
                    current_byte <= data_in[8*counter +: 8];
                    
                    if ((current_byte >= 8'd65 && current_byte <= 8'd90) || 
                        (current_byte >= 8'd97 && current_byte <= 8'd122)) begin
                        temp_byte <= current_byte ^ 8'h20;
                    end else begin
                        temp_byte <= current_byte;
                    end
                    
                    // Write to result register at correct position
                    if (counter < 4'd15) begin
                        result_reg[8*counter +: 8] <= temp_byte;
                        counter <= counter + 4'd1;
                    end else begin
                        // Last byte
                        result_reg[8*4'd15 +: 8] <= temp_byte;
                    end
                end
                
                REVERSE: begin
                    // Reverse the string: output[i] = input[15-i]
                    current_char <= data_in[8*(4'd15 - counter) +: 8];
                    
                    if (counter < 4'd15) begin
                        result_reg[8*counter +: 8] <= current_char;
                        counter <= counter + 4'd1;
                    end else begin
                        // Last byte
                        result_reg[8*4'd15 +: 8] <= current_char;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    result <= result_reg;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state; // Default: stay in current state
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_LETTERS;
                end
            end
            
            CHECK_LETTERS: begin
                if (counter == 4'd15) begin
                    // Finished scanning all 16 bytes
                    if (has_letter) begin
                        next_state = TRANSFORM;
                    end else begin
                        next_state = REVERSE;
                    end
                end
            end
            
            TRANSFORM: begin
                if (counter == 4'd15 && current_byte != 8'd0) begin
                    // Finished transforming, go to DONE
                    next_state = DONE;
                end
            end
            
            REVERSE: begin
                if (counter == 4'd15 && current_char != 8'd0) begin
                    // Finished reversing, go to DONE
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule