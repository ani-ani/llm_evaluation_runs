module word_len(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire valid_in,
    output reg result,
    output reg done
);

// Parameters for string processing
localparam [3:0] MAX_LEN = 4'd16; // Maximum string length
localparam [6:0] CLK_TIMEOUT = 7'd100; // Maximum cycles

// Internal state
reg [3:0] len_counter; // Count characters (0-15)
reg processing;
reg result_reg;
reg [6:0] cycle_counter;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        len_counter <= 4'd0;
        processing <= 1'b0;
        result_reg <= 1'b0;
        done <= 1'b0;
        cycle_counter <= 7'd0;
    end else begin
        if (start && !processing) begin
            // Start new computation
            len_counter <= 4'd0;
            processing <= 1'b1;
            result_reg <= 1'b0;
            done <= 1'b0;
            cycle_counter <= 7'd0;
        end else if (processing) begin
            if (valid_in) begin
                // Count non-zero characters
                if (char_in != 8'h00 && len_counter < MAX_LEN) begin
                    len_counter <= len_counter + 4'd1;
                end
            end
            
            // Check for end condition or timeout
            cycle_counter <= cycle_counter + 7'd1;
            
            if (!valid_in || len_counter >= MAX_LEN || cycle_counter >= CLK_TIMEOUT) begin
                // Compute result: true if length is odd
                result_reg <= (len_counter[0] == 1'b1) && (len_counter > 4'd0);
                done <= 1'b1;
                processing <= 1'b0;
            end
        end else begin
            done <= 1'b0;
        end
    end
end

assign result = result_reg;

endmodule