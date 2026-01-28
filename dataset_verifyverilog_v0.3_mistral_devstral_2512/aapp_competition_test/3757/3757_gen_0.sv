module string_constructor(
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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_N = 3'd1;
    localparam [2:0] CHECK_COND = 3'd2;
    localparam [2:0] BUILD_STRING = 3'd3;
    localparam [2:0] OUTPUT_STRING = 3'd4;
    localparam [2:0] FINISHED = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] n0, n1;
    reg [4:0] i, j;
    reg [4:0] gap [0:15];
    reg [7:0] string_buffer [0:15];
    reg [4:0] buf_len;
    reg [4:0] out_idx;

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
                if ((n0 * n1 == a01 + a10) && (n0 + n1 <= 16)) begin
                    next_state = BUILD_STRING;
                end else begin
                    next_state = FINISHED;
                end
            end
            BUILD_STRING: begin
                if (i >= buf_len) begin
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
            FINISHED: next_state = FINISHED;
            default: next_state = IDLE;
        endcase
    end

    // Output logic and operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            n0 <= 5'd0;
            n1 <= 5'd0;
            i <= 5'd0;
            j <= 5'd0;
            buf_len <= 5'd0;
            out_idx <= 5'd0;
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                gap[k] <= 5'd0;
                string_buffer[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    char <= 8'd0;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
                
                COMPUTE_N: begin
                    // Compute n0 and n1 from triangular numbers
                    integer k;
                    n0 = 5'd0;
                    n1 = 5'd0;
                    for (k = 0; k <= 16; k = k + 1) begin
                        if (k * (k - 1) / 2 == a00) begin
                            n0 = k;
                        end
                        if (k * (k - 1) / 2 == a11) begin
                            n1 = k;
                        end
                    end
                    // Handle special case where all are zero
                    if (a00 == 16'd0 && a01 == 16'd0 && a10 == 16'd0 && a11 == 16'd0) begin
                        n0 = 5'd1;
                        n1 = 5'd0;
                    end
                end
                
                CHECK_COND: begin
                    i = 5'd0;
                    j = 5'd0;
                    buf_len = 5'd0;
                end
                
                BUILD_STRING: begin
                    if (i == 5'd0) begin
                        // Initialize gap array for distribution
                        gap[0] = n0;
                        for (integer k = 1; k < 16; k = k + 1) begin
                            gap[k] = 5'd0;
                        end
                        // Distribute zeros based on a01 value
                        if (n1 > 5'd0 && n0 > 5'd0) begin
                            gap[0] = a01 / n1;
                            gap[1] = n0 - (a01 / n1);
                        end
                    end
                    
                    // Build string buffer
                    if (i < n1) begin
                        // Add zeros for this gap
                        if (j < gap[i]) begin
                            string_buffer[buf_len] = 8'd48; // '0'
                            buf_len = buf_len + 5'd1;
                            j = j + 5'd1;
                        end else begin
                            // Add one after zeros
                            string_buffer[buf_len] = 8'd49; // '1'
                            buf_len = buf_len + 5'd1;
                            i = i + 5'd1;
                            j = 5'd0;
                        end
                    end else if (i == n1 && j < gap[n1]) begin
                        // Add remaining zeros
                        string_buffer[buf_len] = 8'd48; // '0'
                        buf_len = buf_len + 5'd1;
                        j = j + 5'd1;
                    end else if (i == n1) begin
                        // Add final one if needed (rare case)
                        if (n1 > 5'd0 && buf_len > 5'd0 && string_buffer[buf_len - 5'd1] != 8'd49) begin
                            string_buffer[buf_len] = 8'd49; // '1'
                            buf_len = buf_len + 5'd1;
                        end
                        i = i + 5'd1;
                    end
                    
                    // Special case: all zeros
                    if (n1 == 5'd0 && n0 > 5'd0 && i < n0) begin
                        string_buffer[buf_len] = 8'd48; // '0'
                        buf_len = buf_len + 5'd1;
                        i = i + 5'd1;
                    end
                    // Special case: all ones
                    if (n0 == 5'd0 && n1 > 5'd0 && i < n1) begin
                        string_buffer[buf_len] = 8'd49; // '1'
                        buf_len = buf_len + 5'd1;
                        i = i + 5'd1;
                    end
                end
                
                OUTPUT_STRING: begin
                    if (out_idx < buf_len) begin
                        char = string_buffer[out_idx];
                        valid = 1'b1;
                        out_idx = out_idx + 5'd1;
                    end else begin
                        valid = 1'b0;
                        done = 1'b1;
                    end
                end
                
                FINISHED: begin
                    done = 1'b1;
                    valid = 1'b0;
                end
            endcase
        end
    end

endmodule