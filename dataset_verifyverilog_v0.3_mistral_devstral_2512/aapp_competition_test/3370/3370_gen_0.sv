module EagletonTallest (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire signed [31:0] k,
    input wire signed [31:0] h0,
    input wire signed [31:0] h1,
    input wire signed [31:0] h2,
    input wire signed [31:0] h3,
    output reg signed [31:0] result,
    output reg done
);

// Fixed-point Q16.16
// Arithmetic shift right by 1 for division by 2
function signed [31:0] div2;
    input signed [31:0] x;
    begin
        div2 = {x[31], x[31:1]};
    end
endfunction

// State encoding
localparam [2:0] IDLE = 3'd0;
localparam [2:0] START_SCAN = 3'd1;
localparam [2:0] CHECK_HOUSE = 3'd2;
localparam [2:0] UPDATE_HOUSE = 3'd3;
localparam [2:0] NEXT_HOUSE = 3'd4;
localparam [2:0] SCAN_DONE = 3'd5;
localparam [2:0] MAX_COMPUTE = 3'd6;
localparam [2:0] OUTPUT = 3'd7;

reg [2:0] state;
reg [3:0] i;                     // 0-indexed house counter
reg signed [31:0] heights [0:3]; // Current heights
reg changed;                     // Update flag
reg [9:0] iteration_counter;     // Max 1000 scans
reg signed [31:0] left, right, target;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        i <= 4'd0;
        changed <= 1'b0;
        iteration_counter <= 10'd0;
        heights[0] <= 32'd0;
        heights[1] <= 32'd0;
        heights[2] <= 32'd0;
        heights[3] <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Load initial heights
                    if (N >= 1) heights[0] <= h0;
                    if (N >= 2) heights[1] <= h1;
                    if (N >= 3) heights[2] <= h2;
                    if (N >= 4) heights[3] <= h3;
                    i <= 4'd0;
                    changed <= 1'b0;
                    iteration_counter <= 10'd0;
                    state <= START_SCAN;
                end
            end

            START_SCAN: begin
                i <= 4'd0;
                changed <= 1'b0;
                state <= CHECK_HOUSE;
            end

            CHECK_HOUSE: begin
                // Determine left and right neighbors
                left = (i == 4'd0) ? 32'sd0 : heights[i-1];
                right = (i == N-1) ? 32'sd0 : heights[i+1];
                target <= div2(left + right) + k;
                state <= UPDATE_HOUSE;
            end

            UPDATE_HOUSE: begin
                if (heights[i] < target) begin
                    heights[i] <= target;
                    changed <= 1'b1;
                end
                state <= NEXT_HOUSE;
            end

            NEXT_HOUSE: begin
                if (i < N-1) begin
                    i <= i + 4'd1;
                    state <= CHECK_HOUSE;
                end else begin
                    state <= SCAN_DONE;
                end
            end

            SCAN_DONE: begin
                if (changed) begin
                    iteration_counter <= iteration_counter + 10'd1;
                    if (iteration_counter < 10'd1000) begin
                        state <= START_SCAN;
                    end else begin
                        state <= MAX_COMPUTE; // Timeout
                    end
                end else begin
                    state <= MAX_COMPUTE; // Converged
                end
            end

            MAX_COMPUTE: begin
                // Find maximum height
                result <= heights[0];
                if (N > 1 && heights[1] > result) result <= heights[1];
                if (N > 2 && heights[2] > result) result <= heights[2];
                if (N > 3 && heights[3] > result) result <= heights[3];
                state <= OUTPUT;
            end

            OUTPUT: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule