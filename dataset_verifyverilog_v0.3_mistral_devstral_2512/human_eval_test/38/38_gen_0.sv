module cyclic_codec(
    input clk,
    input rst_n,
    input start,
    input mode,
    input [7:0] char_in,
    input valid_in,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    localparam [3:0] MAX_LEN = 4'd16;

    reg [1:0] state, next_state;
    reg [7:0] buffer [0:2];
    reg [3:0] char_count;
    reg [3:0] output_count;
    reg [3:0] idle_cycles;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            char_count <= 4'd0;
            output_count <= 4'd0;
            idle_cycles <= 4'd0;
            buffer[0] <= 8'd0;
            buffer[1] <= 8'd0;
            buffer[2] <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        valid_out = 1'b0;
        char_out = 8'd0;

        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    char_count = 4'd0;
                    output_count = 4'd0;
                    idle_cycles = 4'd0;
                    buffer[0] = 8'd0;
                    buffer[1] = 8'd0;
                    buffer[2] = 8'd0;
                end
            end

            PROCESSING: begin
                if (valid_in) begin
                    // Shift buffer
                    buffer[0] = buffer[1];
                    buffer[1] = buffer[2];
                    buffer[2] = char_in;
                    char_count = char_count + 4'd1;
                end

                // Output logic with 3-cycle delay
                if (char_count >= 3'd3 && output_count < char_count) begin
                    valid_out = 1'b1;
                    if (mode == 1'b0) begin // Encode: BCA
                        case (output_count % 3'd3)
                            3'd0: char_out = buffer[1];
                            3'd1: char_out = buffer[2];
                            3'd2: char_out = buffer[0];
                        endcase
                    end else begin // Decode: CAB
                        case (output_count % 3'd3)
                            3'd0: char_out = buffer[2];
                            3'd1: char_out = buffer[0];
                            3'd2: char_out = buffer[1];
                        endcase
                    end
                    output_count = output_count + 4'd1;
                end

                // Check if done
                if (char_count >= MAX_LEN && !valid_in && output_count >= char_count) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                if (start) begin
                    next_state = PROCESSING;
                    done <= 1'b0;
                    char_count = 4'd0;
                    output_count = 4'd0;
                    buffer[0] = 8'd0;
                    buffer[1] = 8'd0;
                    buffer[2] = 8'd0;
                end else begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule