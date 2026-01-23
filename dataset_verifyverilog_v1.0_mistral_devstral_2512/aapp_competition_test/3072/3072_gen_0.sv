module max_perimeter #(
    parameter MAX_R = 8,
    parameter MAX_C = 8
)(
    input clk,
    input rst_n,
    input start,
    input [3:0] R,
    input [3:0] C,
    input [MAX_R*MAX_C-1:0] grid_flat,
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'b000;
localparam [2:0] INIT_PREFIX = 3'b001;
localparam [2:0] COMPUTE_PREFIX = 3'b010;
localparam [2:0] ITERATE = 3'b011;
localparam [2:0] DONE = 3'b100;

reg [2:0] state;

// Prefix array: 9x9 for MAX_R=8, MAX_C=8
reg [7:0] prefix [0:MAX_R][0:MAX_C];

// Counters for initialization and prefix computation
reg [3:0] init_i, init_j;
reg [3:0] i, j;

// Rectangle counters
reg [3:0] r1, c1, r2, c2;

// Next rectangle counters (combinational)
reg [3:0] next_r1, next_c1, next_r2, next_c2;
reg is_last;

// Max perimeter register
reg [7:0] max_perim;

// Grid value for prefix computation
wire [5:0] grid_index;
wire grid_val;
assign grid_index = i * C + j;
assign grid_val = grid_flat[grid_index];

// Sum computation for current rectangle
wire [7:0] sum;
assign sum = prefix[r2+1][c2+1] - prefix[r1][c2+1] - prefix[r2+1][c1] + prefix[r1][c1];

// Area and perimeter for current rectangle
wire [7:0] width, height, area, perimeter;
assign width = c2 - c1 + 1;
assign height = r2 - r1 + 1;
assign area = width * height;
assign perimeter = (width + height) << 1;

// Combinationally compute next rectangle counters
always @(*) begin
    // Default: stay same
    next_r1 = r1;
    next_c1 = c1;
    next_r2 = r2;
    next_c2 = c2;
    
    // Check if current is last
    is_last = (r1 == R-1) && (c1 == C-1) && (r2 == R-1) && (c2 == C-1);
    
    if (!is_last) begin
        // Increment c2
        if (c2 < C-1) begin
            next_c2 = c2 + 1;
        end else begin
            // c2 == C-1, reset to c1
            next_c2 = c1;
            // Increment r2
            if (r2 < R-1) begin
                next_r2 = r2 + 1;
            end else begin
                // r2 == R-1, reset to r1
                next_r2 = r1;
                // Increment c1
                if (c1 < C-1) begin
                    next_c1 = c1 + 1;
                end else begin
                    // c1 == C-1, reset to 0
                    next_c1 = 0;
                    // Increment r1
                    if (r1 < R-1) begin
                        next_r1 = r1 + 1;
                    end else begin
                        // r1 == R-1, should not happen because is_last would be true
                        next_r1 = r1;
                    end
                end
            end
        end
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        result <= 0;
        max_perim <= 0;
        init_i <= 0;
        init_j <= 0;
        i <= 0;
        j <= 0;
        r1 <= 0;
        c1 <= 0;
        r2 <= 0;
        c2 <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    max_perim <= 0;
                    init_i <= 0;
                    init_j <= 0;
                    state <= INIT_PREFIX;
                end
            end

            INIT_PREFIX: begin
                // Set prefix[init_i][init_j] = 0
                prefix[init_i][init_j] <= 8'd0;
                // Increment init_j
                if (init_j < MAX_C) begin
                    init_j <= init_j + 1;
                end else begin
                    init_j <= 0;
                    if (init_i < MAX_R) begin
                        init_i <= init_i + 1;
                    end else begin
                        // Done initializing
                        i <= 0;
                        j <= 0;
                        state <= COMPUTE_PREFIX;
                    end
                end
            end

            COMPUTE_PREFIX: begin
                // Compute prefix[i+1][j+1] = grid_val + prefix[i][j+1] + prefix[i+1][j] - prefix[i][j]
                prefix[i+1][j+1] <= grid_val + prefix[i][j+1] + prefix[i+1][j] - prefix[i][j];
                // Increment j
                if (j < C - 1) begin
                    j <= j + 1;
                end else begin
                    j <= 0;
                    if (i < R - 1) begin
                        i <= i + 1;
                    end else begin
                        // Done computing prefix
                        r1 <= 0;
                        c1 <= 0;
                        r2 <= 0;
                        c2 <= 0;
                        state <= ITERATE;
                    end
                end
            end

            ITERATE: begin
                // Check if current rectangle is valid
                if (sum == area) begin
                    if (perimeter > max_perim) begin
                        max_perim <= perimeter;
                    end
                end

                // If this is the last rectangle, go to DONE
                if (is_last) begin
                    result <= max_perim - 1;
                    done <= 1;
                    state <= DONE;
                end else begin
                    // Update counters to next rectangle
                    r1 <= next_r1;
                    c1 <= next_c1;
                    r2 <= next_r2;
                    c2 <= next_c2;
                end
            end

            DONE: begin
                // Stay here until reset
                done <= 1;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule