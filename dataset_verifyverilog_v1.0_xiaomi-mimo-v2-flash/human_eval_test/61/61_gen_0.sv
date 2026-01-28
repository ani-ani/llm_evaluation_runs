module bracket_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] string_in,  // 16 bytes x 8 bits = 128 bits packed
    input wire [3:0] length,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] CHECK_CHAR = 2'd1;
    localparam [1:0] CHECK_RESULT = 2'd2;
    localparam [1:0] FINISH     = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] balance_count;      // Track open brackets
    reg [3:0] index;              // Character index (0-15)
    reg [7:0] current_char;       // Current character being checked
    reg is_balanced;              // Internal result flag
    
    // ASCII constants
    localparam [7:0] OPEN_BRACKET  = 8'd40;  // '(' ASCII
    localparam [7:0] CLOSE_BRACKET = 8'd41;  // ')' ASCII

    // Extract current character from string_in
    wire [7:0] char_at_index;
    assign char_at_index = string_in[(index * 8) +: 8];

    // State transition logic (combinational)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_CHAR;
                else
                    next_state = IDLE;
            end
            CHECK_CHAR: begin
                if (index >= length)
                    next_state = CHECK_RESULT;
                else
                    next_state = CHECK_CHAR;
            end
            CHECK_RESULT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            balance_count <= 8'd0;
            index <= 4'd0;
            current_char <= 8'd0;
            is_balanced <= 1'b1;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        balance_count <= 8'd0;
                        index <= 4'd0;
                        is_balanced <= 1'b1;
                    end
                end
                
                CHECK_CHAR: begin
                    if (index < length) begin
                        current_char <= char_at_index;
                        
                        if (char_at_index == OPEN_BRACKET) begin
                            balance_count <= balance_count + 8'd1;
                        end else if (char_at_index == CLOSE_BRACKET) begin
                            if (balance_count > 8'd0) begin
                                balance_count <= balance_count - 8'd1;
                            end else begin
                                is_balanced <= 1'b0;
                            end
                        end
                        index <= index + 4'd1;
                    end
                end
                
                CHECK_RESULT: begin
                    if (is_balanced && (balance_count == 8'd0)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                    balance_count <= 8'd0;
                    index <= 4'd0;
                    is_balanced <= 1'b1;
                end
            endcase
        end
    end

endmodule