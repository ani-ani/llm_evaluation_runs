module lcs_without_virus (
    input clk,
    input rst_n,
    input start,
    input [4:0] s1_char,
    input [4:0] s2_char,
    input [4:0] virus_char,
    input [2:0] idx_s1,
    input [2:0] idx_s2,
    input [2:0] idx_virus,
    input input_valid,
    output reg [3:0] max_length,
    output reg [63:0] result_string,
    output reg done,
    output reg valid
);

parameter S1_LEN = 8;
parameter S2_LEN = 8;
parameter VIRUS_LEN = 3;
parameter CHAR_WIDTH = 5;

reg [4:0] s1_mem [0:S1_LEN-1];
reg [4:0] s2_mem [0:S2_LEN-1];
reg [4:0] virus_mem [0:VIRUS_LEN-1];

reg [2:0] state;
reg [3:0] i, j, k;
reg [3:0] load_idx;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s1_mem <= 0;
        s2_mem <= 0;
        virus_mem <= 0;
        max_length <= 0;
        result_string <= 0;
        done <= 0;
        valid <= 0;
        i <= 0;
        j <= 0;
        k <= 0;
        state <= 3'b000;
        load_idx <= 0;
    end else begin
        case (state)
            3'b000: // IDLE
                if (start) state <= 3'b001;
                else state <= 3'b000;
            3'b001: // LOAD
                if (input_valid) begin
                    s1_mem[idx_s1] <= s1_char;
                    s2_mem[idx_s2] <= s2_char;
                    virus_mem[idx_virus] <= virus_char;
                    load_idx <= load_idx + 1;
                end
                if (load_idx >= (S1_LEN + S2_LEN + VIRUS_LEN)) begin
                    state <= 3'b010;
                end else begin
                    state <= 3'b001;
                end
            3'b010: // BUILD_KMP
                state <= 3'b011;
            3'b011: // INIT_DP
                state <= 3'b100;
            3'b100: // DP_ROW_START
                if (i < S1_LEN) begin
                    i <= i + 1;
                    j <= 0;
                    state <= 3'b101;
                end else begin
                    state <= 3'b110;
                end
            3'b101: // DP_COL_ITERATE
                if (j < S2_LEN) begin
                    j <= j + 1;
                    state <= 3'b101;
                end else begin
                    state <= 3'b100;
                end
            3'b110: // FIND_MAX
                state <= 3'b111;
            3'b111: // DONE
                done <= 1;
                valid <= 1;
                state <= 3'b111;
            default: state <= 3'b000;
        endcase
    end
end

assign result_string = 0;
assign done = state == 3'b111;
assign valid = done;

endmodule