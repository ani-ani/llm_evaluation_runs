module syllable_checker (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] pattern,
    input [127:0] line,
    output reg match,
    output reg done
);

// Internal signals
reg [127:0] captured_line;
reg [3:0] char_count;
reg [7:0] vowel_count;
reg [1:0] state;

localparam IDLE = 2'b00;
localparam CHECK_CHAR = 2'b01;
localparam DONE = 2'b10;

// Combinational match assignment
assign match = (state == DONE) ? (vowel_count == pattern) : 1'b0;

always @(posedge clk) begin
    if (!rst_n) begin
        captured_line <= 128'b0;
        char_count <= 4'b0;
        vowel_count <= 8'b0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: 
                done <= 1'b0;
                if (start) begin
                    captured_line <= line;
                    state <= CHECK_CHAR;
                end else begin
                    state <= IDLE;
                end
            CHECK_CHAR:
                done <= 1'b0;
                reg [7:0] current_char;
                current_char = captured_line[(char_count*8)+7 : char_count*8];
                if (current_char != 32 && (current_char == 8'h61 || current_char ==8'h65 || current_char ==8'h69 || current_char ==8'h6F || current_char ==8'h75 || current_char ==8'h79)) begin
                    vowel_count <= vowel_count + 1;
                end
                char_count <= char_count + 1;
                if (char_count == 16) begin
                    state <= DONE;
                end else begin
                    state <= CHECK_CHAR;
                end
            DONE:
                done <= 1'b1;
                state <= IDLE;
        endcase
    end
end
endmodule