module snake_to_camel (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index,
    input [3:0] num_chars,
    output reg [7:0] char_out,
    output reg [3:0] out_index,
    output reg done
);

localparam IDLE = 4'd0,
          CAP_FIRST = 4'd1,
          CAP_AFTER_UNDERSCORE = 4'd2,
          OUTPUT_CHAR = 4'd3,
          DONE = 4'd4;

reg [2:0] state;
reg [7:0] capitalize_next;
reg [3:0] current_index;
reg [3:0] total_length;
reg [3:0] out_index;

// Default outputs
assign char_out = 8'd0;
assign done = 1'b0;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
capitalize_next <= 4'd0;
current_index <= 4'd0;
total_length <= 4'd0;
out_index <= 4'd0;
done <= 1'b0;
char_out <= 8'd0;
    end else begin
        // Default assignments to prevent latches
        char_out <= char_out;
out_index <= out_index;
done <= done;
state <= state;

        if (state == IDLE) begin
            if (start) begin
                total_length <= num_chars;
current_index <= 4'd0;
out_index <= 4'd0;
                if (total_length > 4'd0) begin
                    state <= CAP_FIRST;
done <= 1'b0;
                end else begin
                    state <= DONE;
done <= 1'b1;
                end
            end
        end else if (state == CAP_FIRST) begin
            if (current_index < total_length) begin
                if (char_in == '_') begin
                    capitalize_next <= 4'd1;
current_index <= current_index + 1;
                    if (current_index < total_length) begin
                        state <= CAP_AFTER_UNDERSCORE;
                    end else begin
                        state <= DONE;
done <= 1'b1;
                    end
                end else begin
                    char_out <= (char_in >= 'a' && char_in <= 'z') ? char_in - 32 : char_in;
                    out_index <= out_index + 1;
current_index <= current_index + 1;
                    if (current_index < total_length) begin
                        state <= OUTPUT_CHAR;
                    end else begin
                        state <= DONE;
done <= 1'b1;
                    end
                end
            end
        end else if (state == CAP_AFTER_UNDERSCORE) begin
            if (current_index < total_length) begin
                if (char_in == '_') begin
                    capitalize_next <= 4'd1;
current_index <= current_index + 1;
                    if (current_index < total_length) begin
                        state <= CAP_AFTER_UNDERSCORE;
                    end else begin
                        state <= DONE;
done <= 1'b1;
                    end
                end else begin
                    char_out <= (char_in >= 'a' && char_in <= 'z') ? char_in - 32 : char_in;
                    out_index <= out_index + 1;
capitalize_next <= 4'd0;
current_index <= current_index + 1;
                    if (current_index < total_length) begin
                        state <= OUTPUT_CHAR;
                    end else begin
                        state <= DONE;
done <= 1'b1;
                    end
                end
            end
        end else if (state == OUTPUT_CHAR) begin
            if (current_index < total_length) begin
                if (char_in == '_') begin
                    capitalize_next <= 4'd1;
current_index <= current_index + 1;
                    if (current_index < total_length) begin
                        state <= CAP_AFTER_UNDERSCORE;
                    end else begin
                        state <= DONE;
done <= 1'b1;
                    end
                end else begin
                    char_out <= char_in;
                    out_index <= out_index + 1;
current_index <= current_index + 1;
                    if (current_index < total_length) begin
                        state <= OUTPUT_CHAR;
                    end else begin
                        state <= DONE;
done <= 1'b1;
                    end
                end
            end
        end
    end
endmodule