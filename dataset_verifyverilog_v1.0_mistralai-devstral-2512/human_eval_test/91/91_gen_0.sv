module BoredomCounter(
    input clk,
    input rst_n,
    input start,
    input [1023:0] str_input,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SCAN      = 2'd1;
    localparam [1:0] CHECK_CHAR = 2'd2;
    localparam [1:0] COMPLETE  = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [6:0] index;
    reg [6:0] boredom_count;
    reg [7:0] current_char;
    reg [7:0] next_char;
    reg delimiter_found;

    // Constants
    localparam [7:0] CHAR_I    = 8'd73;
    localparam [7:0] CHAR_DOT  = 8'd46;
    localparam [7:0] CHAR_QM   = 8'd63;
    localparam [7:0] CHAR_EXCL = 8'd33;
    localparam [6:0] MAX_INDEX = 7'd127;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            index <= 7'd0;
            boredom_count <= 7'd0;
            delimiter_found <= 1'b0;
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
                    next_state = SCAN;
                    index = 7'd0;
                    boredom_count = 7'd0;
                    delimiter_found = 1'b0;
                end
            end

            SCAN: begin
                current_char = str_input[(index * 8) +: 8];
                
                if (current_char == CHAR_DOT || current_char == CHAR_QM || current_char == CHAR_EXCL) begin
                    delimiter_found = 1'b1;
                    next_state = CHECK_CHAR;
                end else begin
                    delimiter_found = 1'b0;
                    if (index == MAX_INDEX) begin
                        next_state = COMPLETE;
                    end else begin
                        index = index + 7'd1;
                    end
                end
            end

            CHECK_CHAR: begin
                if (index < MAX_INDEX) begin
                    next_char = str_input[((index + 7'd1) * 8) +: 8];
                    if (next_char == CHAR_I) begin
                        boredom_count = boredom_count + 7'd1;
                    end
                    index = index + 7'd1;
                    next_state = SCAN;
                end else begin
                    next_state = COMPLETE;
                end
            end

            COMPLETE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(*) begin
        result = 8'd0;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                result = 8'd0;
                done = 1'b0;
            end

            SCAN: begin
                result = boredom_count;
                done = 1'b0;
            end

            CHECK_CHAR: begin
                result = boredom_count;
                done = 1'b0;
            end

            COMPLETE: begin
                result = boredom_count;
                done = 1'b1;
            end

            default: begin
                result = 8'd0;
                done = 1'b0;
            end
        endcase
    end

endmodule