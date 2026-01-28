module decimal_to_binary (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] decimal,
    output reg [95:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CONVERT = 2'd1;
    localparam [1:0] BUILD_STRING = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [1:0] next_state;
    
    // Internal registers
    reg [7:0] binary_value;
    reg [7:0] bit_index;
    reg [7:0] char_value;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // ASCII constants
    localparam [7:0] ASCII_d = 8'h64;
    localparam [7:0] ASCII_b = 8'h62;
    localparam [7:0] ASCII_0 = 8'h30;
    localparam [7:0] ASCII_1 = 8'h31;

    // State transition
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CONVERT : IDLE;
            CONVERT: next_state = BUILD_STRING;
            BUILD_STRING: next_state = (bit_index >= 8'd8) ? FINISH : BUILD_STRING;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 96'd0;
            done <= 1'b0;
            binary_value <= 8'd0;
            bit_index <= 8'd0;
            char_value <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    bit_index <= 8'd0;
                    // Initialize result to zeros
                    result <= 96'd0;
                end
                
                CONVERT: begin
                    // Direct conversion: decimal input IS the binary value
                    binary_value <= decimal;
                    bit_index <= 8'd0;
                end
                
                BUILD_STRING: begin
                    // Build string sequentially
                    if (bit_index == 8'd0) begin
                        // Position 0: 'd'
                        result[7:0] <= ASCII_d;
                        // Position 1: 'b'
                        result[15:8] <= ASCII_b;
                    end
                    
                    // Positions 2-9: binary digits (MSB first)
                    if (bit_index < 8'd8) begin
                        // Calculate which bit position (MSB = bit 7, LSB = bit 0)
                        if (binary_value[7 - bit_index]) begin
                            char_value <= ASCII_1;
                        end else begin
                            char_value <= ASCII_0;
                        end
                        
                        // Map to position in result
                        // bit 7 -> position 2, bit 6 -> position 3, ..., bit 0 -> position 9
                        case (bit_index)
                            8'd0: result[23:16] <= (binary_value[7]) ? ASCII_1 : ASCII_0;
                            8'd1: result[31:24] <= (binary_value[6]) ? ASCII_1 : ASCII_0;
                            8'd2: result[39:32] <= (binary_value[5]) ? ASCII_1 : ASCII_0;
                            8'd3: result[47:40] <= (binary_value[4]) ? ASCII_1 : ASCII_0;
                            8'd4: result[55:48] <= (binary_value[3]) ? ASCII_1 : ASCII_0;
                            8'd5: result[63:56] <= (binary_value[2]) ? ASCII_1 : ASCII_0;
                            8'd6: result[71:64] <= (binary_value[1]) ? ASCII_1 : ASCII_0;
                            8'd7: result[79:72] <= (binary_value[0]) ? ASCII_1 : ASCII_0;
                            default: begin
                                // Do nothing
                            end
                        endcase
                        
                        bit_index <= bit_index + 8'd1;
                    end
                    
                    // Position 10: 'd'
                    if (bit_index == 8'd8) begin
                        result[87:80] <= ASCII_d;
                    end
                    
                    // Position 11: 'b'
                    if (bit_index == 8'd8) begin
                        result[95:88] <= ASCII_b;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 96'd0;
                    done <= 1'b0;
                end
            endcase
            
            // Override done in IDLE if start is high
            if (state == IDLE && start) begin
                done <= 1'b0;
            end
            
            // Prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
            end
        end
    end

endmodule