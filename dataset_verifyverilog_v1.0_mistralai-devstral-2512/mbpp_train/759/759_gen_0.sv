module ascii_decimal_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] idx,
    input last_char,
    output reg valid,
    output reg done,
    output reg [2:0] state_debug
);

    // State declarations
    localparam [2:0] WAIT       = 3'd0;
    localparam [2:0] INT_DIGIT  = 3'd1;
    localparam [2:0] DEC_POINT  = 3'd2;
    localparam [2:0] DEC_DIGIT1 = 3'd3;
    localparam [2:0] DEC_DIGIT2 = 3'd4;
    localparam [2:0] ERROR      = 3'd5;
    localparam [2:0] VALID      = 3'd6;

    reg [2:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= WAIT;
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Handle done and valid signals
            if (state == VALID && last_char) begin
                done <= 1'b1;
                valid <= 1'b1;
            end else begin
                done <= 1'b0;
                if (state != VALID) begin
                    valid <= 1'b0;
                end
            end
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            WAIT: begin
                if (start) begin
                    if (char_in >= 8'd48 && char_in <= 8'd57) begin
                        next_state = INT_DIGIT;
                    end else begin
                        next_state = ERROR;
                    end
                end
            end

            INT_DIGIT: begin
                if (char_in >= 8'd48 && char_in <= 8'd57) begin
                    if (last_char) begin
                        next_state = VALID;
                    end
                end else if (char_in == 8'd46 && !last_char) begin
                    next_state = DEC_POINT;
                end else begin
                    next_state = ERROR;
                end
            end

            DEC_POINT: begin
                if (char_in >= 8'd48 && char_in <= 8'd57) begin
                    next_state = DEC_DIGIT1;
                end else begin
                    next_state = ERROR;
                end
            end

            DEC_DIGIT1: begin
                if (char_in >= 8'd48 && char_in <= 8'd57) begin
                    if (last_char) begin
                        next_state = VALID;
                    end else begin
                        next_state = DEC_DIGIT2;
                    end
                end else begin
                    next_state = ERROR;
                end
            end

            DEC_DIGIT2: begin
                if (char_in >= 8'd48 && char_in <= 8'd57 && last_char) begin
                    next_state = VALID;
                end else begin
                    next_state = ERROR;
                end
            end

            ERROR: begin
                next_state = ERROR;
            end

            VALID: begin
                next_state = VALID;
            end

            default: next_state = WAIT;
        endcase
    end

    // Debug state output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_debug <= 3'd0;
        end else begin
            state_debug <= state;
        end
    end

endmodule