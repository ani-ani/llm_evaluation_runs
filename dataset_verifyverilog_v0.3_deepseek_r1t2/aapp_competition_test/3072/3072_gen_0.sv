module max_perimeter #(
    parameter MAX_R = 8,
    parameter MAX_C = 8
)(
    input clk,
    input rst_n,
    input start,
    input [3:0] R,
    input [3:0] C,
    input [63:0] grid_flat,
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'b000;
localparam [2:0] INIT_PREFIX = 3'b001;
localparam [2:0] COMPUTE_PREFIX = 3'b010;
localparam [2:0] ITERATE = 3'b011;
localparam [2:0] DONE = 3'b100;

reg [2:0] state, next_state;

// Prefix array: 9x9
reg [7:0] prefix[0:8][0:8];

// Counters
reg [3:0] init_i, init_j;
reg [3:0] i, j;
reg [3:0] r1, c1, r2, c2;

// Max perimeter track
reg [15:0] max_perim;

// Combinational signals
wire [63:0] grid_flat_ordered = grid_flat;
wire grid_val = (i < R && j < C) ? grid_flat_ordered[i*C + j] : 1'b0;
wire [7:0] sum = prefix[r2+1][c2+1] - prefix[r1][c2+1] - prefix[r2+1][c1] + prefix[r1][c1];
wire [3:0] width = c2 - c1 + 4'd1;
wire [3:0] height = r2 - r1 + 4'd1;
wire [7:0] area = width * height;
wire [15:0] perimeter = (width + height) * 16'd2;

// Iterators for rectangle
wire last_r1 = (r1 == R-1);
wire last_c1 = (c1 == C-1);
wire last_r2 = (r2 == R-1);
wire last_c2 = (c2 == C-1);
wire is_last = last_r1 & last_c1 & last_r2 & last_c2;

// Next rectangle logic
always @(*) begin
    if (state != ITERATE) begin
        next_state = state;
    end else begin
        if (!is_last) begin
            if (!last_c2) begin
                c2 = c2 + 1;
            end else begin
                c2 = c1;
                if (!last_r2) begin
                    r2 = r2 + 1;
                end else begin
                    r2 = r1;
                    if (!last_c1) begin
                        c1 = c1 + 1;
                    end else begin
                        c1 = 0;
                        if (!last_r1) begin
                            r1 = r1 + 1;
                        end
                    end
                end
            end
            next_state = ITERATE;
        end else begin
            next_state = DONE;
        end
    end
end

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 16'd0;
        max_perim <= 16'd0;
        init_i <= 4'd0;
        init_j <= 4'd0;
        i <= 4'd0;
        j <= 4'd0;
        r1 <= 4'd0;
        c1 <= 4'd0;
        r2 <= 4'd0;
        c2 <= 4'd0;
        for (init_i = 0; init_i <= MAX_R; init_i = init_i + 1) begin
            for (init_j = 0; init_j <= MAX_C; init_j = init_j + 1) begin
                prefix[init_i][init_j] <= 8'd0;
            end
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT_PREFIX;
                    init_i <= 4'd0;
                    init_j <= 4'd0;
                    max_perim <= 16'd0;
                end
            end
            
            INIT_PREFIX: begin
                prefix[init_i][init_j] <= 8'd0;
                if (init_j < MAX_C) begin
                    init_j <= init_j + 1;
                end else begin
                    init_j <= 4'd0;
                    if (init_i < MAX_R) begin
                        init_i <= init_i + 1;
                    end else begin
                        state <= COMPUTE_PREFIX;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
            end
            
            COMPUTE_PREFIX: begin
                if (i < R && j < C) begin
                    prefix[i+1][j+1] <= grid_val + prefix[i][j+1] + prefix[i+1][j] - prefix[i][j];
                end
                if (j < C) begin
                    j <= j + 1;
                end else begin
                    j <= 4'd0;
                    if (i < R) begin
                        i <= i + 1;
                    end else begin
                        state <= ITERATE;
                        r1 <= 4'd0;
                        c1 <= 4'd0;
                        r2 <= 4'd0;
                        c2 <= 4'd0;
                    end
                end
            end
            
            ITERATE: begin
                // Check if rectangle fits
                if (r2 >= r1 && c2 >= c1) begin
                    if (sum == area) begin
                        if (perimeter > max_perim) begin
                            max_perim <= perimeter;
                        end
                    end
                end
                
                if (is_last) begin
                    state <= DONE;
                    result <= (max_perim > 0) ? (max_perim - 16'd1) : 16'd0;
                    done <= 1'b1;
                end else begin
                    // Update rectangle counters
                    {r1, c1, r2, c2} <= {next_r1, next_c1, next_r2, next_c2};
                end
            end
            
            DONE: begin
                done <= 1'b1;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule