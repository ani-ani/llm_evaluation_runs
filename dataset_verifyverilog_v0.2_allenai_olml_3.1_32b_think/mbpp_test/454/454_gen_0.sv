module wordz_matcher (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg match,
    output reg done
);

reg [1:0] state; // 2 bits: 00 IDLE, 01 SCANNING, 10 COMPLETE
reg [4:0] char_count; // 5 bits, up to 16 (10000 is 16)
reg in_word;
reg has_z;
reg match_found;

localparam IDLE = 2'b00;
localparam SCANNING = 2'b01;
localparam COMPLETE = 2'b10;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        char_count <= 5'b0;
        in_word <= 1'b0;
        has_z <= 1'b0;
        match_found <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start == 1) begin
                state <= SCANNING;
                char_count <= 5'b0;
                in_word <= 1'b0;
                has_z <= 1'b0;
                // match_found remains unchanged
            end
        end else if (state == SCANNING) begin
            if (valid_in && char_count < 16) begin
                // process character
                // Check if current character is alphanumeric or underscore
                if ( (char_in >= 'A' && char_in <= 'Z') || (char_in >= 'a' && char_in <= 'z') || (char_in >= '0' && char_in <= '9') || (char_in == '_') ) begin
                    // Inside or entering a word
                    if (!in_word) begin
                        in_word <= 1'b1;
                        has_z <= 1'b0;
                    end
                    if (char_in == 'z' || char_in == 'Z') begin
                        has_z <= 1'b1;
                    end
                end else begin
                    // Not a word character, check if exiting a word
                    if (in_word) begin
                        in_word <= 1'b0;
                        if (has_z) begin
                            if (!match_found) match_found <= 1'b1;
                        end
                    end
                end
                // Increment character count
                char_count <= char_count + 1;
                // Check if we reached 16
                if (char_count == 16) begin
                    state <= COMPLETE;
                end
            end // valid and <16
        end // SCANNING
    end // else not reset
end // always block

// Assign outputs
assign match = match_found;
assign done = (state == COMPLETE);
endmodule