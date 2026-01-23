module string_list_reverse (input clk, input rst_n, // active-low reset input start, input [7:0] char_in, input valid_in, input [2:0] str_len, output reg [7:0] char_out, output reg valid_out, output reg done, output reg [2:0] out_idx);
localparam IDLE = 3'b000;
localparam READ_STR = 3'b001;
localparam REVERSE = 3'b010;
localparam OUTPUT = 3'b011;
localparam DONE = 3'b100;

reg [2:0] state;
reg [1:0] current_string_idx;
reg [2:0] target_length;
reg [2:0] char_count;
reg [2:0] output_index;
reg [7:0][7:0][4] buffer;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        current_string_idx <= 2'b00;
        target_length <= 3'b000;
        char_count <= 3'b000;
        output_index <= 3'b000;
        buffer <= 'b0;
    end else begin
        state <= state;

        if (state == IDLE) begin
            if (start) begin
                state <= READ_STR;
                target_length <= str_len;
                char_count <= 3'b000;
            end
        end else if (state == READ_STR) begin
            if (valid_in) begin
                buffer[current_string_idx][char_count] <= char_in;
                char_count <= char_count + 1;
            end
            if (char_count == target_length) begin
                state <= REVERSE;
            end
        end else if (state == REVERSE) begin
            state <= OUTPUT;
        end else if (state == OUTPUT) begin
            output_index <= output_index - 1;
            if (output_index < 0) begin
                if (current_string_idx < 3) begin
                    state <= READ_STR;
                    current_string_idx <= current_string_idx + 1;
                    target_length <= str_len;
                end else begin
                    state <= DONE;
                end
            end
        end else if (state == DONE) begin
            // stay in DONE
        end
    end
end

// Combinational assignments for outputs
assign char_out = buffer[current_string_idx][output_index];
assign valid_out = (state == OUTPUT) && (output_index >= 0);
assign done = (state == DONE);
assign out_idx = target_length - 1 - output_index;

endmodule