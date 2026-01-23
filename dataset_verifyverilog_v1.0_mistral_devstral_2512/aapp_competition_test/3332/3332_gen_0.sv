module stream_scheduler (
    input clk,
    input rst_n,
    input start,
    input [7:0] s0, d0, p0,
    input [7:0] s1, d1, p1,
    input [7:0] s2, d2, p2,
    input [7:0] s3, d3, p3,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] UPDATE  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Stream data registers
    reg [7:0] s0_reg, d0_reg, p0_reg;
    reg [7:0] s1_reg, d1_reg, p1_reg;
    reg [7:0] s2_reg, d2_reg, p2_reg;
    reg [7:0] s3_reg, d3_reg, p3_reg;

    // Computation variables
    reg [15:0] max_priority;
    reg [15:0] current_priority;
    reg [15:0] e0, e1, e2, e3;
    reg [3:0] subset;
    reg [1:0] pair_idx;
    reg [1:0] i, j;
    reg [3:0] included;
    reg feasible;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            s0_reg <= 8'd0; d0_reg <= 8'd0; p0_reg <= 8'd0;
            s1_reg <= 8'd0; d1_reg <= 8'd0; p1_reg <= 8'd0;
            s2_reg <= 8'd0; d2_reg <= 8'd0; p2_reg <= 8'd0;
            s3_reg <= 8'd0; d3_reg <= 8'd0; p3_reg <= 8'd0;
            max_priority <= 16'd0;
            current_priority <= 16'd0;
            e0 <= 16'd0; e1 <= 16'd0; e2 <= 16'd0; e3 <= 16'd0;
            subset <= 4'd0;
            pair_idx <= 2'd0;
            i <= 2'd0; j <= 2'd0;
            included <= 4'd0;
            feasible <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load input data
                    s0_reg <= s0; d0_reg <= d0; p0_reg <= p0;
                    s1_reg <= s1; d1_reg <= d1; p1_reg <= p1;
                    s2_reg <= s2; d2_reg <= d2; p2_reg <= p2;
                    s3_reg <= s3; d3_reg <= d3; p3_reg <= p3;

                    // Compute end times
                    e0 <= {1'b0, s0_reg} + {1'b0, d0_reg};
                    e1 <= {1'b0, s1_reg} + {1'b0, d1_reg};
                    e2 <= {1'b0, s2_reg} + {1'b0, d2_reg};
                    e3 <= {1'b0, s3_reg} + {1'b0, d3_reg};

                    // Initialize max priority
                    max_priority <= 16'd0;
                    subset <= 4'd0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if all subsets processed
                    if (subset == 4'd16) begin
                        state <= UPDATE;
                    end else begin
                        // Initialize for new subset
                        current_priority <= 16'd0;
                        included <= subset;
                        pair_idx <= 2'd0;
                        feasible <= 1'b1;

                        // Add priorities of included streams
                        if (included[0]) current_priority <= current_priority + {8'b0, p0_reg};
                        if (included[1]) current_priority <= current_priority + {8'b0, p1_reg};
                        if (included[2]) current_priority <= current_priority + {8'b0, p2_reg};
                        if (included[3]) current_priority <= current_priority + {8'b0, p3_reg};

                        // Check all pairs for crossing
                        i <= 2'd0;
                        j <= 2'd1;
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Check if we need to check pairs
                    if (pair_idx < 2'd6) begin
                        // Check if both streams are included
                        if (included[i] && included[j]) begin
                            // Check for crossing intervals
                            reg [15:0] si, ei, sj, ej;
                            case (i)
                                2'd0: begin si = {1'b0, s0_reg}; ei = e0; end
                                2'd1: begin si = {1'b0, s1_reg}; ei = e1; end
                                2'd2: begin si = {1'b0, s2_reg}; ei = e2; end
                                2'd3: begin si = {1'b0, s3_reg}; ei = e3; end
                            endcase

                            case (j)
                                2'd0: begin sj = {1'b0, s0_reg}; ej = e0; end
                                2'd1: begin sj = {1'b0, s1_reg}; ej = e1; end
                                2'd2: begin sj = {1'b0, s2_reg}; ej = e2; end
                                2'd3: begin sj = {1'b0, s3_reg}; ej = e3; end
                            endcase

                            // Check crossing conditions
                            if ((si < sj && sj < ei && ei < ej) || (sj < si && si < ej && ej < ei)) begin
                                feasible <= 1'b0;
                            end
                        end

                        // Move to next pair
                        if (j == 2'd3) begin
                            i <= i + 2'd1;
                            j <= i + 2'd1;
                        end else begin
                            j <= j + 2'd1;
                        end
                        pair_idx <= pair_idx + 2'd1;
                    end else begin
                        // All pairs checked, update max if feasible and higher
                        if (feasible && current_priority > max_priority) begin
                            max_priority <= current_priority;
                        end

                        // Move to next subset
                        subset <= subset + 4'd1;
                        state <= COMPUTE;
                    end
                end

                DONE_STATE: begin
                    result <= max_priority;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule