module DominoColoringCounter(
    input wire rst_n,
    input wire start,
    input wire [7:0] s1_in,
    input wire [7:0] s2_in,
    input wire [5:0] idx_in,
    input wire is_last,
    output reg [31:0] result,
    output reg done
);

    localparam [31:0] MOD = 32'd1000000007;
    localparam [0:0] STATE_VERTICAL = 1'b0;
    localparam [0:0] STATE_HORIZONTAL = 1'b1;

    reg [0:0] state;
    reg [31:0] current_result;
    reg [5:0] current_idx;
    reg processing;

    always @(posedge start or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_VERTICAL;
            current_result <= 32'd0;
            current_idx <= 6'd0;
            result <= 32'd0;
            done <= 1'b0;
            processing <= 1'b0;
        end else if (start && !processing) begin
            processing <= 1'b1;
            current_idx <= 6'd0;
            state <= STATE_VERTICAL;
            current_result <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end
    end

    always @(*) begin
        if (processing) begin
            if (idx_in == current_idx) begin
                if (idx_in == 6'd0) begin
                    if (s1_in == s2_in) begin
                        current_result <= 32'd3;
                        state <= STATE_VERTICAL;
                    end else begin
                        current_result <= 32'd6;
                        state <= STATE_HORIZONTAL;
                    end
                end else begin
                    if (s1_in == s2_in) begin
                        if (state == STATE_VERTICAL) begin
                            current_result <= (current_result * 32'd2) % MOD;
                        end else begin
                            current_result <= current_result % MOD;
                        end
                        state <= STATE_VERTICAL;
                    end else begin
                        if (state == STATE_VERTICAL) begin
                            current_result <= (current_result * 32'd2) % MOD;
                        end else begin
                            current_result <= (current_result * 32'd3) % MOD;
                        end
                        state <= STATE_HORIZONTAL;
                    end
                end
                current_idx <= idx_in + 6'd1;
            end
            if (is_last && (idx_in == current_idx - 6'd1)) begin
                result <= current_result % MOD;
                done <= 1'b1;
                processing <= 1'b0;
            end
        end
    end

endmodule