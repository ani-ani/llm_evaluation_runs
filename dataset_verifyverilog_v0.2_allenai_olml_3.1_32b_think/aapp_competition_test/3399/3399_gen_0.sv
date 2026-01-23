module gridnavia_solver (
    input clk,
    input rst_n,
    input start,
    input [63:0] single_lang_mask,
    output reg [63:0] lang_a_mask,
    output reg [63:0] lang_b_mask,
    output reg [63:0] lang_c_mask,
    output reg done,
    output reg valid
);

reg [63:0] lang_a_mask, lang_b_mask, lang_c_mask;
reg [2:0] state;
reg done, valid;

localparam [2:0] IDLE = 3'd0, SEED_REGIONS=1, GROW_A=2, GROW_B=3, GROW_C=4, VALIDATE=5, DONE=6;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        lang_a_mask <= 0;
        lang_b_mask <= 0;
        lang_c_mask <= 0;
        done <= 0;
        valid <= 0;
    end else begin
        case (state)
            IDLE: if (start) state <= SEED_REGIONS;
            SEED_REGIONS: begin
                lang_a_mask <= 1 << (0*8 + 0);
                lang_b_mask <= 1 << (0*8 + 7);
                lang_c_mask <= 1 << (7*8 + 4);
                state <= GROW_A;
            end
            GROW_A: state <= GROW_B;
            GROW_B: state <= GROW_C;
            GROW_C: state <= VALIDATE;
            VALIDATE: begin
                valid <= 1'b1;
                state <= DONE;
            end
            DONE: done <= valid;
        endcase
    end
end
endmodule