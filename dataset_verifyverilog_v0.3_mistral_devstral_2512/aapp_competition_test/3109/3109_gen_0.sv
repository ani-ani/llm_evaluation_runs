module sand_art_balancer #(
    parameter N = 4,
    parameter M = 4,
    parameter DATA_WIDTH = 32,
    parameter MAX_CYCLES = 1000
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] volumes [M-1:0],
    input wire [DATA_WIDTH-1:0] min_vals [N-1:0][M-1:0],
    input wire [DATA_WIDTH-1:0] max_vals [N-1:0][M-1:0],
    input wire [DATA_WIDTH-1:0] widths [N-1:0],
    input wire [3:0] num_sections,
    input wire [3:0] num_colors,
    output reg [DATA_WIDTH-1:0] min_difference,
    output reg done,
    output reg error
);

    reg [3:0] state;
    reg [DATA_WIDTH-1:0] current_diff;
    reg [DATA_WIDTH-1:0] best_diff;
    reg [3:0] section_idx;
    reg [3:0] color_idx;
    reg [DATA_WIDTH-1:0] allocation [N-1:0][M-1:0];
    reg [DATA_WIDTH-1:0] total_heights [N-1:0];
    reg [9:0] cycle_count;

    localparam IDLE = 0;
    localparam COMPUTE_HEIGHTS = 1;
    localparam CALCULATE_DIFF = 2;
    localparam UPDATE_BEST = 3;
    localparam NEXT_ALLOCATION = 4;
    localparam FINISHED = 5;

    function automatic [DATA_WIDTH-1:0] mul_fixed;
        input [DATA_WIDTH-1:0] a, b;
        begin
            mul_fixed = (a * b) >> 16;
        end
    endfunction

    function automatic [DATA_WIDTH-1:0] div_fixed;
        input [DATA_WIDTH-1:0] a, b;
        begin
            div_fixed = (a << 16) / b;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            best_diff <= {1'b0, {DATA_WIDTH-1{1'b1}}};
            min_difference <= 32'd0;
            cycle_count <= 10'd0;
            section_idx <= 4'd0;
            color_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        if (num_sections > N || num_colors > M) begin
                            error <= 1'b1;
                            state <= FINISHED;
                        end else begin
                            section_idx <= 4'd0;
                            color_idx <= 4'd0;
                            state <= COMPUTE_HEIGHTS;
                        end
                    end
                end

                COMPUTE_HEIGHTS: begin
                    if (section_idx < num_sections) begin
                        total_heights[section_idx] <= 32'd0;
                        color_idx <= 4'd0;
                        state <= CALCULATE_DIFF;
                    end else begin
                        state <= CALCULATE_DIFF;
                    end
                end

                CALCULATE_DIFF: begin
                    if (section_idx < num_sections) begin
                        if (color_idx < num_colors) begin
                            total_heights[section_idx] <= total_heights[section_idx] + allocation[section_idx][color_idx];
                            color_idx <= color_idx + 4'd1;
                        end else begin
                            total_heights[section_idx] <= div_fixed(total_heights[section_idx], widths[section_idx]);
                            section_idx <= section_idx + 4'd1;
                            state <= COMPUTE_HEIGHTS;
                        end
                    end else begin
                        state <= UPDATE_BEST;
                    end
                end

                UPDATE_BEST: begin
                    current_diff <= 32'd0;
                    if (current_diff < best_diff) begin
                        best_diff <= current_diff;
                    end
                    state <= NEXT_ALLOCATION;
                end

                NEXT_ALLOCATION: begin
                    state <= FINISHED;
                end

                FINISHED: begin
                    min_difference <= best_diff;
                    done <= 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule