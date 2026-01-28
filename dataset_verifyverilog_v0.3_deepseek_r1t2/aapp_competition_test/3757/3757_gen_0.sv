module string_constructor (
    input clk,
    input rst_n,
    input start,
    input [15:0] a00,
    input [15:0] a01,
    input [15:0] a10,
    input [15:0] a11,
    output reg [7:0] char,
    output reg valid,
    output reg done
);

    // Parameters
    parameter MAX_LEN = 16;
    parameter MAX_N = 16;
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] COMPUTE_N   = 3'd1;
    localparam [2:0] CHECK_COND  = 3'd2;
    localparam [2:0] BUILD_STR   = 3'd3;
    localparam [2:0] OUTPUT_STR  = 3'd4;
    localparam [2:0] FINISHED    = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] n0, n1;
    reg [4:0] i, j;
    reg [4:0] gap [0:MAX_N];
    reg [7:0] string_buf [0:MAX_LEN-1];
    reg [4:0] buf_len;
    reg [4:0] out_idx;
    reg [7:0] cycle_count;

    // Helper function: Find triangular number
    function automatic [4:0] find_n;
        input [15:0] val;
        reg [15:0] tri;
        integer k;
        begin
            find_n = 5'd0;
            for (k = 0; k <= MAX_N; k = k + 1) begin
                tri = (k * (k - 1)) >> 1;
                if (tri == val) begin
                    find_n = k;
                end
            end
        end
    endfunction

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            n0 <= 5'd0;
            n1 <= 5'd0;
            i <= 5'd0;
            j <= 5'd0;
            buf_len <= 5'd0;
            out_idx <= 5'd0;
            cycle_count <= 8'd0;
            // Initialize arrays
            for (integer m = 0; m <= MAX_N; m = m + 1) begin
                gap[m] <= 5'd0;
            end
            for (integer n = 0; n < MAX_LEN; n = n + 1) begin
                string_buf[n] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:       if (start) next_state = COMPUTE_N;
            COMPUTE_N:  next_state = CHECK_COND;
            CHECK_COND: if ((n0 * n1 == (a01 + a10)) && (n0 + n1 <= MAX_LEN))
                            next_state = BUILD_STR;
                        else
                            next_state = FINISHED;
            BUILD_STR:  if (buf_len == (n0 + n1) || (cycle_count >= 8'd100))
                            next_state = OUTPUT_STR;
            OUTPUT_STR: if (out_idx >= buf_len)
                            next_state = FINISHED;
            FINISHED:   next_state = FINISHED;
            default:    next_state = IDLE;
        endcase
    end

    // Output and processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state register block
        end else begin
            case (state)
                IDLE: begin
                    char <= 8'd0;
                    valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                COMPUTE_N: begin
                    n0 <= find_n(a00);
                    n1 <= find_n(a11);
                    // All-zero special case
                    if (a00 == 16'd0 && a01 == 16'd0 &&
                        a10 == 16'd0 && a11 == 16'd0) begin
                        n0 <= 5'd1;
                        n1 <= 5'd0;
                    end
                end
                CHECK_COND: begin
                    i <= 5'd0;
                    j <= 5'd0;
                    buf_len <= 5'd0;
                    gap[0] <= n0;
                    // Initialize gap array
                    if (n1 > 5'd0) begin
                        gap[0] <= a01 / n1;
                        gap[1] <= n0 - (a01 / n1);
                    end
                end
                BUILD_STR: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (n1 == 5'd0 && i < n0) begin
                        string_buf[buf_len] <= "0";
                        buf_len <= buf_len + 5'd1;
                        i <= i + 5'd1;
                    end
                    else if (n0 == 5'd0 && i < n1) begin
                        string_buf[buf_len] <= "1";
                        buf_len <= buf_len + 5'd1;
                        i <= i + 5'd1;
                    end
                    else if (i < n1) begin
                        if (j < gap[i]) begin
                            string_buf[buf_len] <= "0";
                            buf_len <= buf_len + 5'd1;
                            j <= j + 5'd1;
                        end else begin
                            string_buf[buf_len] <= "1";
                            buf_len <= buf_len + 5'd1;
                            i <= i + 5'd1;
                            j <= 5'd0;
                        end
                    end
                    else if (i == n1 && j < gap[n1]) begin
                        string_buf[buf_len] <= "0";
                        buf_len <= buf_len + 5'd1;
                        j <= j + 5'd1;
                    end
                end
                OUTPUT_STR: begin
                    if (out_idx < buf_len) begin
                        char <= string_buf[out_idx];
                        valid <= 1'b1;
                        out_idx <= out_idx + 5'd1;
                    end else begin
                        valid <= 1'b0;
                        done <= 1'b1;
                    end
                end
                FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule