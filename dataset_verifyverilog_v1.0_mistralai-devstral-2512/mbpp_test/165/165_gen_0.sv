module char_position_counter(
    input clk,
    input rst_n,
    input start,
    input [127:0] string_input,
    input [3:0] string_len,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] count;
    reg [3:0] i;
    reg [7:0] current_char;
    reg [7:0] upper_char;
    reg is_match;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            count <= 4'd0;
            i <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end
            end
            PROCESSING: begin
                if (i == string_len - 1) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 4'd0;
            i <= 4'd0;
            current_char <= 8'd0;
            upper_char <= 8'd0;
            is_match <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    count <= 4'd0;
                    i <= 4'd0;
                    done <= 1'b0;
                end
                PROCESSING: begin
                    // Extract current character
                    current_char <= string_input[8*i +: 8];
                    
                    // Convert to uppercase
                    upper_char <= current_char | 32'd32;
                    
                    // Check if position matches alphabet index
                    is_match <= (upper_char == (8'h41 + i));
                    
                    // Update counter
                    if (is_match) begin
                        count <= count + 4'd1;
                    end
                    
                    // Move to next character
                    i <= i + 4'd1;
                end
                DONE_STATE: begin
                    result <= count;
                    done <= 1'b1;
                end
                default: begin
                    count <= 4'd0;
                    i <= 4'd0;
                end
            endcase
        end
    end

endmodule