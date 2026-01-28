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

localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE_HEIGHTS = 3'd1;
localparam [2:0] CALCULATE_DIFF = 3'd2;
localparam [2:0] UPDATE_BEST = 3'd3;
localparam [2:0] NEXT_ALLOCATION = 3'd4;
localparam [2:0] FINISHED = 3'd5;

reg [2:0] state, next_state;
reg [DATA_WIDTH-1:0] current_diff;
reg [DATA_WIDTH-1:0] best_diff;
reg [3:0] section_idx;
reg [3:0] color_idx;
reg [7:0] cycle_count;
reg [DATA_WIDTH-1:0] allocation [N-1:0][M-1:0];
reg [DATA_WIDTH-1:0] total_heights [N-1:0];

integer i, j;

function automatic [DATA_WIDTH-1:0] mul_fixed;
    input [DATA_WIDTH-1:0] a, b;
    reg [2*DATA_WIDTH-1:0] product;
    begin
        product = a * b;
        mul_fixed = product[47:16];
    end
endfunction

function automatic [DATA_WIDTH-1:0] div_fixed;
    input [DATA_WIDTH-1:0] a, b;
    reg [2*DATA_WIDTH-1:0] dividend;
    begin
        dividend = {a, {DATA_WIDTH{1'b0}}};
        div_fixed = dividend / b;
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        error <= 1'b0;
        best_diff <= {1'b0, {DATA_WIDTH-1{1'b1}}};
        min_difference <= {DATA_WIDTH{1'b0}};
        current_diff <= {DATA_WIDTH{1'b0}};
        section_idx <= 4'd0;
        color_idx <= 4'd0;
        cycle_count <= 8'd0;
        
        for (i = 0; i < N; i = i + 1) begin
            total_heights[i] <= {DATA_WIDTH{1'b0}};
            for (j = 0; j < M; j = j + 1) begin
                allocation[i][j] <= {DATA_WIDTH{1'b0}};
            end
        end
    end else begin
        cycle_count <= cycle_count + 8'd1;
        
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
                        state <= COMPUTE_HEIGHTS;
                    end
                end
            end
            
            COMPUTE_HEIGHTS: begin
                if (section_idx < num_sections) begin
                    total_heights[section_idx] <= {DATA_WIDTH{1'b0}};
                    color_idx <= 4'd0;
                    state <= CALCULATE_DIFF;
                end else begin
                    state <= UPDATE_BEST;
                end
            end
            
            CALCULATE_DIFF: begin
                if (section_idx < num_sections) begin
                    if (color_idx < num_colors) begin
                        total_heights[section_idx] <= total_heights[section_idx] + 
                            allocation[section_idx][color_idx];
                        color_idx <= color_idx + 4'd1;
                    end else begin
                        total_heights[section_idx] <= div_fixed(
                            total_heights[section_idx], 
                            widths[section_idx]
                        );
                        section_idx <= section_idx + 4'd1;
                        state <= COMPUTE_HEIGHTS;
                    end
                end
            end
            
            UPDATE_BEST: begin
                current_diff <= {DATA_WIDTH{1'b0}};
                section_idx <= 4'd0;
                state <= NEXT_ALLOCATION;
            end
            
            NEXT_ALLOCATION: begin
                min_difference <= best_diff;
                state <= FINISHED;
            end
            
            FINISHED: begin
                done <= 1'b1;
                if (!start) state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
        
        if (cycle_count >= MAX_CYCLES) begin
            error <= 1'b1;
            state <= FINISHED;
        end
    end
end

endmodule
