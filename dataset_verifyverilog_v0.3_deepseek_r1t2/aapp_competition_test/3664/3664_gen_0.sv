module zamboni(
    input clk,
    input rst_n,
    input start,
    input [7:0] i,
    input [7:0] j,
    input [7:0] n,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] INIT        = 4'd1;
    localparam [3:0] CHECK_ITER  = 4'd2;
    localparam [3:0] MOVE_START  = 4'd3;
    localparam [3:0] MOVE_STEP   = 4'd4;
    localparam [3:0] NEXT_ITER   = 4'd5;
    localparam [3:0] MARK_FINAL  = 4'd6;
    localparam [3:0] DONE_ST     = 4'd7;

    reg [3:0] state, next_state;
    
    // Grid memory (8x8)
    reg [7:0] grid [0:7][0:7];

    // Position counters (0-based)
    reg [2:0] current_i, current_j;

    // Control registers
    reg [1:0] direction;  // 0=right, 1=down, 2=left, 3=up
    reg [7:0] color;      // 0-25 for letters (A=1), 27=@
    reg [7:0] stepSize;
    reg [7:0] moveCount;
    reg [7:0] iterations;

    integer x, y;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            
            // Initialize grid
            for (x = 0; x < 8; x = x + 1)
                for (y = 0; y < 8; y = y + 1)
                    grid[x][y] <= 8'd0;

            current_i <= 3'd0;
            current_j <= 3'd0;
            direction <= 2'd0;
            color <= 8'd0;
            stepSize <= 8'd1;
            moveCount <= 8'd0;
            iterations <= 8'd0;
        end
        else begin
            state <= next_state;

            case (state)
                INIT: begin
                    // Initialize starting position (convert 1-based to 0-based)
                    current_i <= i[2:0] - 3'd1;
                    current_j <= j[2:0] - 3'd1;
                    color <= 8'd0;
                    stepSize <= 8'd1;
                    iterations <= 8'd0;
                    direction <= 2'd0;
                end

                MOVE_STEP: begin
                    // Update position based on direction (wrapping)
                    case (direction)
                        2'd0: current_j <= (current_j == 3'd7) ? 3'd0 : current_j + 3'd1; // right
                        2'd1: current_i <= (current_i == 3'd7) ? 3'd0 : current_i + 3'd1; // down
                        2'd2: current_j <= (current_j == 3'd0) ? 3'd7 : current_j - 3'd1; // left
                        2'd3: current_i <= (current_i == 3'd0) ? 3'd7 : current_i - 3'd1; // up
                    endcase

                    // Update grid with current color (store color+1)
                    grid[current_i][current_j] <= color + 8'd1;

                    moveCount <= moveCount + 8'd1;
                end

                NEXT_ITER: begin
                    stepSize <= stepSize + 8'd1;
                    direction <= (direction + 2'd1) % 2'd4;
                    color <= (color + 8'd1) % 8'd26;  // Cycle A-Z
                    iterations <= iterations + 8'd1;
                end

                MARK_FINAL: begin
                    grid[current_i][current_j] <= 8'd27; // Mark with '@'
                end

                DONE_ST: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE:       next_state = start ? INIT : IDLE;
            INIT:       next_state = CHECK_ITER;
            CHECK_ITER: next_state = (iterations >= n) ? MARK_FINAL : MOVE_START;
            MOVE_START: begin
                next_state = MOVE_STEP;
                moveCount = 8'd0;
            end
            MOVE_STEP:  next_state = (moveCount >= stepSize - 8'd1) ? NEXT_ITER : MOVE_STEP;
            NEXT_ITER:  next_state = CHECK_ITER;
            MARK_FINAL: next_state = DONE_ST;
            DONE_ST:    next_state = DONE_ST;
            default:    next_state = IDLE;
        endcase
    end

endmodule