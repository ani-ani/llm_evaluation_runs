module ip_remove_leading_zeros (
    input clk,
    input rst_n,
    input start,
    input [119:0] ip_in,
    output reg [119:0] ip_out,
    output reg done
);

    // State machine states
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam WAIT = 2'b10;
    localparam DONE_ST = 2'b11;

    reg [1:0] state;
    reg [5:0] count; // Counter for 50 cycles
    reg [119:0] result_buffer; // Holds the computed result

    // Byte decomposition
    wire [7:0] in [14:0];
    genvar g;
    generate
        for (g = 0; g < 15; g = g + 1) begin : gen_in
            assign in[g] = ip_in[119 - 8*g -: 8];
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ip_out <= 120'h202020202020202020202020202020;
            done <= 1'b0;
            count <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        count <= 6'd1;
                    end
                end

                PROCESS: begin
                    state <= WAIT;
                    count <= 6'd2; // Start counting wait cycles
                end

                WAIT: begin
                    if (count < 50) begin
                        count <= count + 1;
                    end else begin
                        state <= DONE_ST;
                    end
                end

                DONE_ST: begin
                    ip_out <= result_buffer;
                    done <= 1'b1;
                    state <= IDLE; // Wait for next start
                end
            endcase
        end
    end

    // Combinational Result Calculation
    always @(*) begin
        integer i;
        reg [7:0] out_bytes [14:0];
        reg [3:0] write_ptr; // Pointer in output buffer

        // Initialize output buffer with spaces
        for (i = 0; i < 15; i = i + 1) begin
            out_bytes[i] = 8'h20;
        end

        write_ptr = 0;

        // Process 4 octets
        for (i = 0; i < 4; i = i + 1) begin
            reg [7:0] b0, b1, b2;
            reg [3:0] start_idx;
            reg [3:0] len;
            reg [3:0] first_non_zero;
            reg [3:0] k;

            // Select bytes based on octet index
            case (i)
                0: begin b0 = in[0]; b1 = in[1]; b2 = in[2]; start_idx = 0; end
                1: begin b0 = in[4]; b1 = in[5]; b2 = in[6]; start_idx = 4; end
                2: begin b0 = in[8]; b1 = in[9]; b2 = in[10]; start_idx = 8; end
                3: begin b0 = in[12]; b1 = in[13]; b2 = in[14]; start_idx = 12; end
            endcase

            // Determine length
            len = 0;
            if (b0 >= 8'h30 && b0 <= 8'h39) len = 1;
            if (b1 >= 8'h30 && b1 <= 8'h39 && len > 0) len = 2;
            if (b2 >= 8'h30 && b2 <= 8'h39 && len > 1) len = 3;

            // Find first non-zero
            first_non_zero = len;
            if (len > 0) begin
                if (b0 != 8'h30) first_non_zero = 0;
                else if (len > 1 && b1 != 8'h30) first_non_zero = 1;
                else if (len > 2 && b2 != 8'h30) first_non_zero = 2;
            end

            // Write logic
            if (len > 0) begin
                if (first_non_zero < len) begin
                    // Non-zero found, write stripped digits
                    for (k = 0; k < (len - first_non_zero); k = k + 1) begin
                        case (first_non_zero + k)
                            0: out_bytes[start_idx + k] = b0;
                            1: out_bytes[start_idx + k] = b1;
                            2: out_bytes[start_idx + k] = b2;
                        endcase
                    end
                    // Write dot (except for last octet)
                    if (i < 3) out_bytes[start_idx + (len - first_non_zero)] = 8'h2E;
                end else begin
                    // All zeros, keep one
                    out_bytes[start_idx] = 8'h30;
                    if (i < 3) out_bytes[start_idx + 1] = 8'h2E;
                end
            end
        end

        // Pack to result_buffer
        result_buffer = {
            out_bytes[0], out_bytes[1], out_bytes[2], out_bytes[3],
            out_bytes[4], out_bytes[5], out_bytes[6], out_bytes[7],
            out_bytes[8], out_bytes[9], out_bytes[10], out_bytes[11],
            out_bytes[12], out_bytes[13], out_bytes[14]
        };
    end

endmodule
