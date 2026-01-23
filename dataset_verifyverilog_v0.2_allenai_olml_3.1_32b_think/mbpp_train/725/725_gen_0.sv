module quotation_extractor (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [5:0] char_index,
    output reg [127:0] extracted [0:7],
    output reg [3:0] extracted_count,
    output reg done,
    output reg error
);

localparam IDLE = 3'b000;
localparam SCANNING = 3'b001;
localparam CAPTURING = 3'b010;
localparam DONE_STATE = 3'b100;

reg [2:0] state;
reg [3:0] substring_count;
reg [2:0] next_substring_index;
reg [127:0] current_substring;
reg [3:0] current_length;
reg done;
reg error;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        substring_count <= 4'd0;
        next_substring_index <= 3'd0;
        current_substring <= 128'd0;
        current_length <= 4'd0;
        error <= 1'b0;
        done <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= SCANNING;
                substring_count <= 4'd0;
                next_substring_index <= 3'd0;
                current_substring <= 128'd0;
                current_length <= 4'd0;
                error <= 1'b0;
            end
        end else if (state == SCANNING) begin
            if (char_in == 34) begin // opening quote
                if (substring_count < 4'd8) begin
                    state <= CAPTURING;
                    current_substring <= 128'd0;
                    current_length <= 4'd0;
                end
            end
            // Check if last character
            if (char_index == 6'd63) begin
                state <= DONE_STATE;
                done <= 1'b1;
            end
        end else if (state == CAPTURING) begin
            if (char_in == 34) begin // closing quote
                if (current_length <= 16) begin
                    extracted[next_substring_index] <= current_substring;
                    next_substring_index <= next_substring_index + 1;
                    substring_count <= substring_count + 1;
                end
                // Check length error
                if (current_length > 16) begin
                    error <= 1'b1;
                end
                state <= SCANNING;
            end else begin
                if (current_length < 16) begin
                    current_substring = current_substring | (char_in << (current_length * 8));
                    current_length <= current_length + 1;
                end else begin
                    error <= 1'b1;
                end
            end
            // Check if last character
            if (char_index == 6'd63) begin
                if (state == CAPTURING) begin
                    error <= error | 1'b1;
                end
                state <= DONE_STATE;
                done <= 1'b1;
            end
        end else if (state == DONE_STATE) begin
            // stay in done
        end
    end
end

// Assign outputs
assign extracted_count = substring_count;
assign done = done;
assign error = error;

endmodule