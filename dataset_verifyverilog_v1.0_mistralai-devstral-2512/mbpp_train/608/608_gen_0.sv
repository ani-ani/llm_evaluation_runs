module BellNumber(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_ROW = 2'd1;
    localparam [1:0] COMPUTE_COL = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] i, j;
    reg [15:0] bell [0:8][0:8];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_ROW;
                end
            end
            COMPUTE_ROW: begin
                if (i == 4'd0) begin
                    next_state = COMPUTE_COL;
                end else if (i == n) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE_ROW;
                end
            end
            COMPUTE_COL: begin
                if (j == i) begin
                    next_state = COMPUTE_ROW;
                end else begin
                    next_state = COMPUTE_COL;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all bell values to 0
            integer k, l;
            for (k = 0; k < 9; k = k + 1) begin
                for (l = 0; l < 9; l = l + 1) begin
                    bell[k][l] <= 16'd0;
                end
            end
            i <= 4'd0;
            j <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                COMPUTE_ROW: begin
                    if (i == 4'd0) begin
                        // Initialize bell[0][0] = 1
                        bell[0][0] <= 16'd1;
                        i <= 4'd1;
                        j <= 4'd0;
                    end else if (i <= n) begin
                        // Set bell[i][0] = bell[i-1][i-1]
                        bell[i][0] <= bell[i-1][i-1];
                        j <= 4'd1;
                    end
                end
                COMPUTE_COL: begin
                    if (j < i) begin
                        // Compute bell[i][j] = bell[i-1][j-1] + bell[i][j-1]
                        bell[i][j] <= bell[i-1][j-1] + bell[i][j-1];
                        j <= j + 4'd1;
                    end else begin
                        i <= i + 4'd1;
                        j <= 4'd0;
                    end
                end
                FINISH: begin
                    result <= bell[n][0];
                    done <= 1'b1;
                end
                default: begin
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter to prevent infinite loops
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end
            end
        end
    end

endmodule