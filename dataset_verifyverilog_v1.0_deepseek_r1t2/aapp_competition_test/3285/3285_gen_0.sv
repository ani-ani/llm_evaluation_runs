module sds_module (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] r,
    input wire [7:0] m,
    output reg [7:0] n,
    output reg found,
    output reg done
);

localparam MAX_N = 64;
localparam MAX_M = 256;
localparam VAL_WIDTH = 16;

localparam [3:0] 
    IDLE             = 4'd0,
    FIND_D           = 4'd1,
    SEARCH_D         = 4'd2,
    COMPUTE_A        = 4'd3,
    UPDATE_VALUE     = 4'd4,
    UPDATE_DIFF_INIT = 4'd5,
    UPDATE_DIFF      = 4'd6,
    CHECK            = 4'd7,
    DONE_STATE       = 4'd8;

reg [3:0] state, next_state;
reg [7:0] current_d;
reg [VAL_WIDTH-1:0] A_vals [0:MAX_N-1];
reg [MAX_M-1:0] seen;
reg [15:0] new_A;
reg [7:0] i;
reg found_in_diff;

integer s_idx, j_idx;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        n <= 8'd0;
        found <= 1'b0;
        done <= 1'b0;
        current_d <= 8'd0;
        new_A <= 16'd0;
        i <= 8'd0;
        found_in_diff <= 1'b0;
        for (s_idx = 0; s_idx < MAX_M; s_idx = s_idx + 1) begin
            seen[s_idx] <= 1'b0;
        end
        for (j_idx = 0; j_idx < MAX_N; j_idx = j_idx + 1) begin
            A_vals[j_idx] <= 16'd0;
        end
    end else begin
        state <= next_state;
        done <= 1'b0;
        found <= 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    A_vals[0] <= {8'b0, r};
                    seen[r] <= 1'b1;
                    n <= 8'd1;
                    current_d <= 8'd1;
                    found_in_diff <= (r == m);
                    next_state <= (r == m) ? DONE_STATE : FIND_D;
                end else begin
                    next_state <= IDLE;
                end
            end

            FIND_D: begin
                current_d <= 8'd1;
                next_state <= SEARCH_D;
            end

            SEARCH_D: begin
                if (current_d <= 8'(MAX_M)) begin
                    if (!seen[current_d]) begin
                        next_state <= COMPUTE_A;
                    end else begin
                        current_d <= current_d + 8'd1;
                        next_state <= SEARCH_D;
                    end
                end else begin
                    next_state <= COMPUTE_A;
                end
            end

            COMPUTE_A: begin
                new_A <= A_vals[n-1] + {8'd0, current_d};
                next_state <= UPDATE_VALUE;
            end

            UPDATE_VALUE: begin
                A_vals[n] <= new_A;
                n <= n + 8'd1;
                if (new_A <= 16'(MAX_M)) begin
                    seen[new_A[7:0]] <= 1'b1;
                    if (new_A[7:0] == m) found_in_diff <= 1'b1;
                end
                next_state <= UPDATE_DIFF_INIT;
            end

            UPDATE_DIFF_INIT: begin
                i <= 8'd0;
                next_state <= UPDATE_DIFF;
            end

            UPDATE_DIFF: begin
                if (new_A > A_vals[i]) begin
                    reg [15:0] diff;
                    diff = new_A - A_vals[i];
                    if (diff <= 16'(MAX_M)) begin
                        seen[diff[7:0]] <= 1'b1;
                        if (diff[7:0] == m) found_in_diff <= 1'b1;
                    end
                end
                i <= i + 8'd1;
                if (i < n - 8'd1) begin
                    next_state <= UPDATE_DIFF;
                end else begin
                    next_state <= CHECK;
                end
            end

            CHECK: begin
                if (found_in_diff || seen[m]) begin
                    found_in_diff <= 1'b0;
                    next_state <= DONE_STATE;
                end else if (n < 8'(MAX_N)) begin
                    next_state <= FIND_D;
                end else begin
                    next_state <= DONE_STATE;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                found <= (found_in_diff || seen[m]);
                next_state <= IDLE;
                found_in_diff <= 1'b0;
            end

            default: next_state <= IDLE;
        endcase
    end
end

endmodule