module CriticalElements(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] seq [0:15],
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_DP_F = 2'd1;
    localparam [1:0] COMPUTE_DP_B = 2'd2;
    localparam [1:0] FIND_CRITICAL = 2'd3;
    localparam [1:0] FINISH = 2'd4;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // DP arrays
    reg [3:0] dp_f [0:15];
    reg [3:0] dp_b [0:15];
    reg [3:0] lis_length;

    // Critical element tracking
    reg [15:0] critical_mask;
    reg [7:0] critical_count;

    // Iteration counters
    reg [3:0] i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            lis_length <= 4'd0;
            critical_mask <= 16'd0;
            critical_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;

            // Initialize DP arrays
            for (k = 0; k < 16; k = k + 1) begin
                dp_f[k] <= 4'd0;
                dp_b[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_DP_F;
                        i <= 4'd0;
                        j <= 4'd0;
                        // Initialize dp_f
                        for (k = 0; k < 16; k = k + 1) begin
                            dp_f[k] <= 4'd1;
                        end
                    end
                end

                COMPUTE_DP_F: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < len) begin
                        if (j < i) begin
                            if (seq[j] < seq[i] && dp_f[j] + 1 > dp_f[i]) begin
                                dp_f[i] <= dp_f[j] + 1;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        // Find LIS length
                        lis_length <= 4'd0;
                        for (k = 0; k < len; k = k + 1) begin
                            if (dp_f[k] > lis_length) begin
                                lis_length <= dp_f[k];
                            end
                        end
                        state <= COMPUTE_DP_B;
                        i <= 4'd0;
                        j <= 4'd0;
                        // Initialize dp_b
                        for (k = 0; k < 16; k = k + 1) begin
                            dp_b[k] <= 4'd1;
                        end
                    end
                end

                COMPUTE_DP_B: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < len) begin
                        if (j < i) begin
                            if (seq[j] > seq[i] && dp_b[j] + 1 > dp_b[i]) begin
                                dp_b[i] <= dp_b[j] + 1;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        state <= FIND_CRITICAL;
                        i <= 4'd0;
                        critical_mask <= 16'd0;
                        critical_count <= 8'd0;
                    end
                end

                FIND_CRITICAL: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < len) begin
                        if (dp_f[i] + dp_b[i] - 1 == lis_length) begin
                            // Check if this element is critical
                            reg critical;
                            reg [3:0] count;
                            reg [3:0] l;

                            critical = 1'b1;
                            count = 4'd0;

                            // Check if there's another element with same value in LIS
                            for (l = 0; l < len; l = l + 1) begin
                                if (l != i && seq[l] == seq[i] && dp_f[l] + dp_b[l] - 1 == lis_length) begin
                                    critical = 1'b0;
                                end
                            end

                            // Check if removing this element allows another LIS of same length
                            if (critical) begin
                                // Set the bit corresponding to the value (value-1)
                                critical_mask[seq[i] - 1] <= 1'b1;
                                critical_count <= critical_count + 8'd1;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result[23:8] <= critical_mask;
                    result[7:0] <= critical_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 24'd0;
                end
            endcase
        end
    end
endmodule