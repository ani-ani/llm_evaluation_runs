module substitution_cipher_decoder (
    input clk,
    input rst_n,
    input start,
    input [63:0] encrypted_text,
    input [5:0] text_length,
    output reg [63:0] plaintext,
    output reg [255:0] mapping,
    output reg valid,
    output reg done,
    output reg ambiguous
);

reg [2:0] state;
reg [63:0] plaintext_reg;
reg [255:0] mapping_reg;
reg valid_reg, done_reg, ambiguous_reg;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0;
        plaintext_reg <= 64'd0;
        mapping_reg <= 256'd0;
        valid_reg <= 1'b0;
        done_reg <= 1'b0;
        ambiguous_reg <= 1'b0;
    end else begin
        case (state)
            3'd0: // IDLE
                if (start)
                    state <= 3'd1;
                else
                    state <= 3'd0;
                break;
            3'd1: // PREPARE
                state <= 3'd2;
                break;
            3'd2: // GENERATE_CANDIDATES
                state <= 3'd3;
                break;
            3'd3: // VERIFY
                valid_reg <= 1'b0;
                ambiguous_reg <= 1'b0;
                done_reg <= 1'b1;
                state <= 3'd4;
                break;
            3'd4: // DONE
                state <= 3'd4;
                break;
            default: state <= 3'd0;
        endcase
    end
end

assign plaintext = plaintext_reg;
assign mapping = mapping_reg;
assign valid = valid_reg;
assign done = done_reg;
assign ambiguous = ambiguous_reg;
endmodule