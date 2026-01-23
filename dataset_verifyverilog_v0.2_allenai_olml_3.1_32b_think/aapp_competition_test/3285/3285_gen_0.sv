module sds_finder (
    input clk,
    input rst_n, // active low
    input start,
    input [15:0] r,
    input [27:0] m,
    output reg [13:0] result,
    output reg done,
    output reg found
);
// Internal signals
reg [2:0] state;
// is_in_S: track up to 40000
reg [40000:0] is_in_S;
// For d_candidate, max possible d is up to 40000, but 16 bits enough
reg [15:0] d_candidate;
// sequence memory: last 16 terms
reg [31:0] seq_mem [15:0];
// n counter, up to 10000 (14 bits)
reg [13:0] n;
reg [31:0] a_prev;
// outputs
reg [13:0] result_reg;
reg done_flag, found_flag;

// State definitions
localparam IDLE = 3'd0,
INIT = 3'd1,
CHECK_EXISTING = 3'd2,
COMPUTE_NEXT = 3'd3,
UPDATE_SET = 3'd4,
CHECK_COMPLETE = 3'd5,
DONE = 3'd6;

// Default assignments to avoid latches
always @(*) begin
    state <= IDLE;
    is_in_S <= 0;
    d_candidate <= 0;
    seq_mem <= 0;
    n <= 0;
    a_prev <= 0;
    result_reg <= 0;
    done_flag <= 0;
    found_flag <= 0;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        is_in_S <= 0;
        d_candidate <= 0;
        seq_mem <= 0;
        n <= 0;
        a_prev <= 0;
        result_reg <= 0;
        done_flag <= 0;
        found_flag <= 0;
    end else begin
        state <= state; // default hold
        is_in_S <= is_in_S;
        case (state)
        IDLE: begin
            if (start) begin
                state <= INIT;
            end else begin
                state <= IDLE;
            end
        end
        INIT: begin
            is_in_S[r] = 1;
            seq_mem <= {r, 16{32'b0}};
            a_prev <= r;
            n <= 1;
            state <= CHECK_EXISTING;
        end
        CHECK_EXISTING: begin
            if (m <= 40000 && is_in_S[m]) begin
                found_flag <= 1;
                result_reg <= n;
                state <= DONE;
            end else begin
                state <= COMPUTE_NEXT;
                d_candidate <= 1;
            end
        end
        COMPUTE_NEXT: begin
            if (d_candidate <= 40000 && !is_in_S[d_candidate]) begin
                state <= UPDATE_SET;
            end else begin
                if (d_candidate < 40000) begin
                    d_candidate <= d_candidate + 1;
                end
                state <= COMPUTE_NEXT;
            end
        end
        UPDATE_SET: begin
            reg [31:0] a_next;
            a_next = a_prev + d_candidate;
            if (a_next <= 40000) begin
                is_in_S[a_next] = 1;
            end
            seq_mem <= {a_next, seq_mem[14:0]};
            for (int i=1; i<16; i++) begin
                if (seq_mem[i] != 0) begin
                    is_in_S[a_next - seq_mem[i]] = 1;
                end
            end
            n <= n + 1;
            a_prev <= a_next;
            state <= CHECK_COMPLETE;
        end
        CHECK_COMPLETE: begin
            if (n > 10000) begin
                found_flag <= 0;
                state <= DONE;
            end else begin
                if (m <= 40000 && is_in_S[m]) begin
                    found_flag <= 1;
                    result_reg <= n;
                    state <= DONE;
                end else begin
                    state <= COMPUTE_NEXT;
                end
            end
        end
        DONE: state <= DONE;
        default: state <= IDLE;
        endcase
    end
end

assign result = result_reg;
assign done = done_flag;
assign found = found_flag;
endmodule