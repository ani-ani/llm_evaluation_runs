module case_flipper(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input [2:0] char_index,
    output reg [7:0] char_out,
    output reg [2:0] char_out_index,
    output reg char_out_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INPUT     = 3'd1;
    localparam [2:0] OUTPUT    = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;
    reg [2:0] input_count;
    reg [2:0] output_count;
    reg [7:0] char_buffer [0:7];
    integer i;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            input_count <= 3'd0;
            output_count <= 3'd0;
            char_out <= 8'd0;
            char_out_index <= 3'd0;
            char_out_valid <= 1'b0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                char_buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INPUT;
                    input_count = 3'd0;
                    output_count = 3'd0;
                    char_out_valid = 1'b0;
                    done = 1'b0;
                end else begin
                    next_state = IDLE;
                end
            end

            INPUT: begin
                if (char_valid && char_index < 3'd8) begin
                    char_buffer[char_index] = char_in;
                    if (char_index == 3'd7) begin
                        next_state = OUTPUT;
                    end else begin
                        next_state = INPUT;
                    end
                end else if (!start) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = INPUT;
                end
            end

            OUTPUT: begin
                if (output_count < 3'd7) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(*) begin
        case (state)
            IDLE: begin
                char_out = 8'd0;
                char_out_index = 3'd0;
                char_out_valid = 1'b0;
                done = 1'b0;
            end

            INPUT: begin
                char_out = 8'd0;
                char_out_index = 3'd0;
                char_out_valid = 1'b0;
                done = 1'b0;
            end

            OUTPUT: begin
                char_out = char_buffer[output_count];
                char_out_index = output_count;
                char_out_valid = 1'b1;
                done = 1'b0;
            end

            DONE_STATE: begin
                char_out = char_buffer[3'd7];
                char_out_index = 3'd7;
                char_out_valid = 1'b1;
                done = 1'b1;
            end

            default: begin
                char_out = 8'd0;
                char_out_index = 3'd0;
                char_out_valid = 1'b0;
                done = 1'b0;
            end
        endcase
    end

    // Case flipping logic
    always @(*) begin
        if (char_in >= 8'd65 && char_in <= 8'd90) begin
            char_buffer[char_index] = char_in + 8'd32;
        end else if (char_in >= 8'd97 && char_in <= 8'd122) begin
            char_buffer[char_index] = char_in - 8'd32;
        end else begin
            char_buffer[char_index] = char_in;
        end
    end

    // Counter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_count <= 3'd0;
            output_count <= 3'd0;
        end else begin
            case (state)
                INPUT: begin
                    if (char_valid && char_index < 3'd8) begin
                        input_count <= char_index + 3'd1;
                    end
                end

                OUTPUT: begin
                    if (output_count < 3'd7) begin
                        output_count <= output_count + 3'd1;
                    end
                end

                DONE_STATE: begin
                    output_count <= 3'd0;
                end

                default: begin
                    input_count <= 3'd0;
                    output_count <= 3'd0;
                end
            endcase
        end
    end

endmodule