module CircularIntervalCovering(
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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_INPUTS = 3'd1;
    localparam [2:0] INIT = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] subset;
    reg [3:0] min_cameras;
    reg [3:0] current_count;
    reg [15:0] coverage;
    reg [15:0] all_ones;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // Generate all_ones mask based on n_in
    always @(*) begin
        all_ones = 16'd0;
        case (n_in)
            4'd3: all_ones = 16'h0007;
            4'd4: all_ones = 16'h000F;
            4'd5: all_ones = 16'h001F;
            4'd6: all_ones = 16'h003F;
            4'd7: all_ones = 16'h007F;
            4'd8: all_ones = 16'h00FF;
            4'd9: all_ones = 16'h01FF;
            4'd10: all_ones = 16'h03FF;
            4'd11: all_ones = 16'h07FF;
            4'd12: all_ones = 16'h0FFF;
            4'd13: all_ones = 16'h1FFF;
            4'd14: all_ones = 16'h3FFF;
            4'd15: all_ones = 16'h7FFF;
            4'd16: all_ones = 16'hFFFF;
            default: all_ones = 16'd0;
        endcase
    end

    // Coverage calculation for current subset
    always @(*) begin
        integer i;
        coverage = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (subset[i] && cam_valid_in[i]) begin
                if (cam_start_in[i] <= cam_end_in[i]) begin
                    coverage = coverage | ((1 << (cam_end_in[i] - cam_start_in[i] + 1)) - 1) << (cam_start_in[i] - 1);
                end else begin
                    coverage = coverage | ((1 << (n_in - cam_start_in[i] + 1)) - 1) << (cam_start_in[i] - 1);
                    coverage = coverage | ((1 << cam_end_in[i]) - 1);
                end
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset <= 16'd0;
            min_cameras <= 4'd0;
            current_count <= 4'd0;
            result <= 4'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        next_state = CHECK_INPUTS;
                    end else begin
                        next_state = IDLE;
                    end
                end

                CHECK_INPUTS: begin
                    if (n_in < 4'd3 || n_in > 4'd16 || k_in > 4'd16) begin
                        error <= 1'b1;
                        next_state = IDLE;
                    end else begin
                        error <= 1'b0;
                        next_state = INIT;
                    end
                end

                INIT: begin
                    subset <= 16'd0;
                    min_cameras <= 4'd16;  // Initialize to max possible
                    current_count <= 4'd0;
                    cycle_count <= 8'd0;
                    next_state = COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current subset covers all walls
                    if ((coverage & all_ones) == all_ones) begin
                        // Count number of cameras in this subset
                        integer count = 0;
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (subset[i] && cam_valid_in[i]) begin
                                count = count + 1;
                            end
                        end
                        current_count = count;
                        
                        // Update minimum
                        if (current_count < min_cameras) begin
                            min_cameras = current_count;
                        end
                    end
                    
                    // Move to next subset
                    subset <= subset + 16'd1;
                    
                    // Check if done with all subsets or max cycles reached
                    if (subset == 16'd0 || cycle_count >= MAX_CYCLES) begin
                        next_state = FINISH;
                    end else begin
                        next_state = COMPUTE;
                    end
                end

                FINISH: begin
                    if (min_cameras == 4'd16) begin
                        result <= 4'd0;  // Impossible
                    end else begin
                        result <= min_cameras;
                    end
                    done <= 1'b1;
                    next_state = IDLE;
                end

                default: next_state = IDLE;
            endcase
        end
    end

endmodule