module skyline_builder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] block_heights [0:14],
    input wire [15:0] building_targets [0:14],
    input wire [3:0] N_val,
    input wire [3:0] S_val,
    output reg result_valid,
    output reg result_done,
    output reg [3:0] current_building,
    output reg [15:0] blocks_used_mask,
    output reg [3:0] num_blocks_used
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK_SUM = 4'd1;
    localparam [3:0] PARTITION_START = 4'd2;
    localparam [3:0] FIND_SUBSET = 4'd3;
    localparam [3:0] UPDATE_USED = 4'd4;
    localparam [3:0] FINISHED = 4'd5;
    localparam [3:0] IMPOSSIBLE = 4'd6;

    reg [3:0] state, next_state;

    // Internal registers
    reg [31:0] total_blocks_sum;
    reg [31:0] total_buildings_sum;
    reg [3:0] building_idx;
    reg [15:0] used_blocks_mask;
    reg [15:0] subset_mask;
    reg [31:0] subset_sum;
    reg [31:0] current_target;
    reg subset_found;
    reg [15:0] i;
    reg [15:0] j;

    // Cycle counter to prevent infinite loops
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd50000;

    // Compute total sums
    always @(*) begin
        total_blocks_sum = 0;
        for (i = 0; i < 15; i = i + 1) begin
            if (i < N_val) begin
                total_blocks_sum = total_blocks_sum + {16'd0, block_heights[i]};
            end
        end
    end

    always @(*) begin
        total_buildings_sum = 0;
        for (i = 0; i < 15; i = i + 1) begin
            if (i < S_val) begin
                total_buildings_sum = total_buildings_sum + {16'd0, building_targets[i]};
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            result_done <= 1'b0;
            current_building <= 4'd0;
            blocks_used_mask <= 16'd0;
            num_blocks_used <= 4'd0;
            building_idx <= 4'd0;
            used_blocks_mask <= 16'd0;
            subset_mask <= 16'd0;
            subset_sum <= 32'd0;
            current_target <= 32'd0;
            subset_found <= 1'b0;
            cycle_count <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    result_done <= 1'b0;
                    current_building <= 4'd0;
                    blocks_used_mask <= 16'd0;
                    num_blocks_used <= 4'd0;
                    building_idx <= 4'd0;
                    used_blocks_mask <= 16'd0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= CHECK_SUM;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_SUM: begin
                    if (total_blocks_sum == total_buildings_sum) begin
                        next_state <= PARTITION_START;
                    end else begin
                        next_state <= IMPOSSIBLE;
                    end
                end

                PARTITION_START: begin
                    building_idx <= 4'd0;
                    used_blocks_mask <= 16'd0;
                    next_state <= FIND_SUBSET;
                end

                FIND_SUBSET: begin
                    current_building <= building_idx;
                    current_target <= {16'd0, building_targets[building_idx]};
                    subset_mask <= 16'd0;
                    subset_sum <= 32'd0;
                    subset_found <= 1'b0;
                    i <= 16'd0;
                    j <= 16'd0;
                    next_state <= FIND_SUBSET;
                end

                UPDATE_USED: begin
                    used_blocks_mask <= used_blocks_mask | subset_mask;
                    building_idx <= building_idx + 4'd1;
                    if (building_idx == S_val) begin
                        next_state <= FINISHED;
                    end else begin
                        next_state <= FIND_SUBSET;
                    end
                end

                FINISHED: begin
                    result_valid <= 1'b1;
                    result_done <= 1'b1;
                    blocks_used_mask <= used_blocks_mask;
                    num_blocks_used <= $clog2(used_blocks_mask) + 1'b1;
                    next_state <= IDLE;
                end

                IMPOSSIBLE: begin
                    result_valid <= 1'b0;
                    result_done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            
            // Cycle counter increment
            if (state != IDLE && state != FINISHED && state != IMPOSSIBLE) begin
                cycle_count <= cycle_count + 16'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IMPOSSIBLE;
                end
            end
        end
    end

    // Subset sum search logic
    always @(posedge clk) begin
        if (state == FIND_SUBSET) begin
            if (!subset_found) begin
                if (i < 15) begin
                    if (i < N_val && !(used_blocks_mask[i])) begin
                        subset_mask[i] <= 1'b1;
                        subset_sum <= subset_sum + {16'd0, block_heights[i]};
                        if (subset_sum == current_target) begin
                            subset_found <= 1'b1;
                            next_state <= UPDATE_USED;
                        end else if (subset_sum < current_target) begin
                            i <= i + 16'd1;
                        end else begin
                            subset_mask[i] <= 1'b0;
                            subset_sum <= subset_sum - {16'd0, block_heights[i]};
                            i <= i + 16'd1;
                        end
                    end else begin
                        i <= i + 16'd1;
                    end
                end else begin
                    if (subset_sum == current_target) begin
                        subset_found <= 1'b1;
                        next_state <= UPDATE_USED;
                    end else begin
                        next_state <= IMPOSSIBLE;
                    end
                end
            end
        end
    end

endmodule