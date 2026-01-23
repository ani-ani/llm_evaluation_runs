module typo_detector(input clk, input rst_n, input in_valid, input [63:0] in_word, input in_is_last, output out_valid, output [63:0] out_word, output done);

parameter CHARS = 8;
parameter MAX_WORDS = 16;
parameter WORD_BITS = CHARS * 8;

reg [WORD_BITS-1:0] mem [0:MAX_WORDS-1];
reg [WORD_BITS-1:0] current_word;
reg [2:0] state;
reg [3:0] write_ptr;
reg is_last;

// Default assignments
always @(*) begin
    is_last = 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 0;
        write_ptr <= 0;
        current_word <= 0;
        mem <= {MAX_WORDS{{WORD_BITS{1'b0}}}};
    end else begin
        case (state)
            0: // IDLE
                if (in_valid) begin
                    current_word <= in_word;
                    state <= 1;
                end
            end
            1: // LOAD
                mem[write_ptr] <= current_word;
                write_ptr <= write_ptr + 1;
                is_last <= in_is_last;
                if (is_last) begin
                    state <= 2;
                end else begin
                    state <= 2;
                end
            end
            2: // CHECK
                if (is_last) begin
                    state <= 3;
                end else begin
                    state <= 0;
                end
            end
            3: // FINISH
                // Stay in FINISH
            endcase
        end
    end

// Outputs
assign out_valid = 0;
assign out_word = 64'b0;
assign done = (state == 3);

endmodule