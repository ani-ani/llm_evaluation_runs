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

// State definitions
localparam [2:0] IDLE         = 3'd0;
localparam [2:0] COMPUTE_N    = 3'd1;
localparam [2:0] CHECK_COND   = 3'd2;
localparam [2:0] BUILD_STRING = 3'd3;
localparam [2:0] OUTPUT_STRING = 3'd4;
localparam [2:0] FINISHED     = 3'd5;

// Internal registers
reg [2:0] state, next_state;
reg [4:0] n0, n1;
reg [4:0] i, j;
reg [4:0] gap [0:15];
reg [7:0] string_buffer [0:15];
reg [4:0] buf_len;
reg [4:0] out_idx;
reg [15:0] cycle_counter;

// Helper: find n such that n*(n-1)/2 == val
function [4:0] find_n;
    input [15:0] val;
    reg [15:0] tri;
    reg [4:0] k;
    begin
        find_n = 0;
        for (k = 0; k <= 16; k = k + 1) begin
            tri = k * (k - 1) / 2;
            if (tri == val) begin
                find_n = k;
            end
        end
    end
endfunction

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = COMPUTE_N;
        end
        COMPUTE_N: begin
            next_state = CHECK_COND;
        end
        CHECK_COND: begin
            if (((n0 * n1) == (a01 + a10)) && ((n0 + n1) <= 16) && ((n0 + n1) > 0)) begin
                next_state = BUILD_STRING;
            end else begin
                next_state = FINISHED;
            end
        end
        BUILD_STRING: begin
            if (i >= n1 && j >= gap[n1] && !(n0 == 0 && n1 > 0 && i < n1) && !(n1 == 0 && n0 > 0 && i < n0)) begin
                next_state = OUTPUT_STRING;
            end else begin
                next_state = BUILD_STRING;
            end
        end
        OUTPUT_STRING: begin
            if (out_idx >= buf_len) begin
                next_state = FINISHED;
            end else begin
                next_state = OUTPUT_STRING;
            end
        end
        FINISHED: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Output logic and operations
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        char <= 8'b0;
        valid <= 1'b0;
        done <= 1'b0;
        n0 <= 5'd0;
        n1 <= 5'd0;
        i <= 5'd0;
        j <= 5'd0;
        buf_len <= 5'd0;
        out_idx <= 5'd0;
        cycle_counter <= 16'd0;
    end else begin
        case (state)
            IDLE: begin
                char <= 8'b0;
                valid <= 1'b0;
                done <= 1'b0;
                cycle_counter <= 16'd0;
            end
            
            COMPUTE_N: begin
                n0 <= find_n(a00);
                n1 <= find_n(a11);
                if (a00 == 0 && a01 == 0 && a10 == 0 && a11 == 0) begin
                    n0 <= 5'd1;
                    n1 <= 5'd0;
                end
            end
            
            CHECK_COND: begin
                i <= 5'd0;
                j <= 5'd0;
                buf_len <= 5'd0;
                out_idx <= 5'd0;
            end
            
            BUILD_STRING: begin
                cycle_counter <= cycle_counter + 16'd1;
                
                if (i == 0) begin
                    gap[0] <= 5'd0;
                    gap[1] <= 5'd0;
                    gap[2] <= 5'd0;
                    gap[3] <= 5'd0;
                    gap[4] <= 5'd0;
                    gap[5] <= 5'd0;
                    gap[6] <= 5'd0;
                    gap[7] <= 5'd0;
                    gap[8] <= 5'd0;
                    gap[9] <= 5'd0;
                    gap[10] <= 5'd0;
                    gap[11] <= 5'd0;
                    gap[12] <= 5'd0;
                    gap[13] <= 5'd0;
                    gap[14] <= 5'd0;
                    gap[15] <= 5'd0;
                    
                    if (n1 > 5'd0 && n0 > 5'd0) begin
                        gap[0] <= a01 / n1;
                        gap[1] <= n0 - (a01 / n1);
                    end else if (n1 == 5'd0 && n0 > 5'd0) begin
                        gap[0] <= n0;
                    end
                end
                
                if (n0 == 0 && n1 > 0 && i < n1) begin
                    if (buf_len < 16) begin
                        string_buffer[buf_len] <= "1";
                        buf_len <= buf_len + 5'd1;
                        i <= i + 5'd1;
                    end
                end else if (n1 == 0 && n0 > 0 && i < n0) begin
                    if (buf_len < 16) begin
                        string_buffer[buf_len] <= "0";
                        buf_len <= buf_len + 5'd1;
                        i <= i + 5'd1;
                    end
                end else if (i < n1) begin
                    if (j < gap[i]) begin
                        if (buf_len < 16) begin
                            string_buffer[buf_len] <= "0";
                            buf_len <= buf_len + 5'd1;
                            j <= j + 5'd1;
                        end
                    end else begin
                        if (buf_len < 16) begin
                            string_buffer[buf_len] <= "1";
                            buf_len <= buf_len + 5'd1;
                            i <= i + 5'd1;
                            j <= 5'd0;
                        end
                    end
                end else if (i == n1 && j < gap[n1]) begin
                    if (buf_len < 16) begin
                        string_buffer[buf_len] <= "0";
                        buf_len <= buf_len + 5'd1;
                        j <= j + 5'd1;
                    end
                end else if (i == n1 && n1 > 0 && buf_len > 0 && string_buffer[buf_len-5'd1] != "1") begin
                    if (buf_len < 16) begin
                        string_buffer[buf_len] <= "1";
                        buf_len <= buf_len + 5'd1;
                        i <= i + 5'd1;
                    end
                end
            end
            
            OUTPUT_STRING: begin
                if (out_idx < buf_len) begin
                    char <= string_buffer[out_idx];
                    valid <= 1'b1;
                    out_idx <= out_idx + 5'd1;
                end else begin
                    valid <= 1'b0;
                    done <= 1'b1;
                end
            end
            
            FINISHED: begin
                done <= 1'b1;
                valid <= 1'b0;
                char <= 8'b0;
            end
            
            default: begin
                char <= 8'b0;
                valid <= 1'b0;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule