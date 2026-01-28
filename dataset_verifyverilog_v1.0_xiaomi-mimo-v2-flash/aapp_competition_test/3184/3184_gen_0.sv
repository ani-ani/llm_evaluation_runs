module circular_cover(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] k_in,
    input [3:0] cam_start_in [0:15],
    input [3:0] cam_end_in [0:15],
    input [15:0] cam_valid_in,
    output reg [3:0] result,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_IN  = 3'd1;
    localparam [2:0] INIT_SUB  = 3'd2;
    localparam [2:0] GEN_COV   = 3'd3;
    localparam [2:0] CHECK_COV = 3'd4;
    localparam [2:0] UPDATE    = 3'd5;
    localparam [2:0] NEXT_SUB  = 3'd6;
    localparam [2:0] FINISH    = 3'd7;

    reg [2:0] state, next_state;
    
    // Registers
    reg [3:0] N_reg;
    reg [3:0] K_reg;
    reg [15:0] valid_reg;
    reg [3:0] start_arr [0:15];
    reg [3:0] end_arr [0:15];
    
    reg [15:0] subset;          // Current subset mask
    reg [15:0] subset_next;     // Next subset mask
    reg [3:0] cam_count;        // Popcount of current subset
    reg [3:0] min_cameras;      // Best solution so far
    reg [15:0] coverage;        // Current coverage mask
    reg [3:0] cam_idx;          // Index for camera iteration
    reg [15:0] cov_temp;        // Temporary coverage for current camera
    reg [3:0] start_idx;        // Camera start index (0-based)
    reg [3:0] end_idx;          // Camera end index (0-based)
    reg [4:0] i;                // Loop counter
    reg [4:0] cycle_count;      // Cycle counter for safety
    localparam [4:0] MAX_CYCLES = 5'd20; // Conservative limit per operation

    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            error <= 1'b0;
            N_reg <= 4'd0;
            K_reg <= 4'd0;
            valid_reg <= 16'd0;
            for (j = 0; j < 16; j = j + 1) begin
                start_arr[j] <= 4'd0;
                end_arr[j] <= 4'd0;
            end
            subset <= 16'd0;
            subset_next <= 16'd0;
            cam_count <= 4'd0;
            min_cameras <= 4'd15;
            coverage <= 16'd0;
            cam_idx <= 4'd0;
            cov_temp <= 16'd0;
            start_idx <= 4'd0;
            end_idx <= 4'd0;
            i <= 5'd0;
            cycle_count <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        state <= CHECK_IN;
                        N_reg <= n_in;
                        K_reg <= k_in;
                        valid_reg <= cam_valid_in;
                        // Copy arrays
                        for (j = 0; j < 16; j = j + 1) begin
                            start_arr[j] <= cam_start_in[j];
                            end_arr[j] <= cam_end_in[j];
                        end
                    end
                end

                CHECK_IN: begin
                    if ((N_reg < 4'd3) || (N_reg > 4'd16) || (K_reg > 4'd16)) begin
                        error <= 1'b1;
                        result <= 4'd0;
                        state <= FINISH;
                    end else begin
                        state <= INIT_SUB;
                        subset <= 16'd0;
                        min_cameras <= 4'd15;
                    end
                end

                INIT_SUB: begin
                    subset_next <= subset + 16'd1;
                    cam_count <= 4'd0;
                    coverage <= 16'd0;
                    cam_idx <= 4'd0;
                    i <= 5'd0;
                    // Count bits in subset
                    for (i = 0; i < 16; i = i + 1) begin
                        if (subset[i]) cam_count <= cam_count + 4'd1;
                    end
                    state <= GEN_COV;
                end

                GEN_COV: begin
                    if (cam_idx < K_reg) begin
                        if (subset[cam_idx] && valid_reg[cam_idx]) begin
                            // Generate coverage for this camera
                            start_idx <= start_arr[cam_idx] - 4'd1;
                            end_idx <= end_arr[cam_idx] - 4'd1;
                            cov_temp <= 16'd0;
                            state <= CHECK_COV;
                        end else begin
                            cam_idx <= cam_idx + 4'd1;
                            state <= GEN_COV;
                        end
                    end else begin
                        state <= UPDATE;
                    end
                end

                CHECK_COV: begin
                    if (start_idx <= end_idx) begin
                        // Non-wrapping
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i >= start_idx && i <= end_idx) cov_temp[i] <= 1'b1;
                        end
                    end else begin
                        // Wrapping
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i >= start_idx || i <= end_idx) cov_temp[i] <= 1'b1;
                        end
                    end
                    coverage <= coverage | cov_temp;
                    cam_idx <= cam_idx + 4'd1;
                    state <= GEN_COV;
                end

                UPDATE: begin
                    // Check if all N walls covered
                    if (coverage[15:0] >= ((1 << N_reg) - 1)) begin
                        if (cam_count < min_cameras) begin
                            min_cameras <= cam_count;
                        end
                    end
                    state <= NEXT_SUB;
                end

                NEXT_SUB: begin
                    if (subset_next < (16'd1 << K_reg)) begin
                        subset <= subset_next;
                        cycle_count <= cycle_count + 5'd1;
                        if (cycle_count >= MAX_CYCLES) begin
                            // Timeout safety
                            state <= FINISH;
                        end else begin
                            state <= INIT_SUB;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    if (min_cameras > 4'd15) begin
                        result <= 4'd0; // Impossible
                    end else begin
                        result <= min_cameras;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule