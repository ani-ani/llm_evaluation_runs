module LifeguardPositionCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [7:0] x0, y0, x1, y1, x2, y2, x3, y3,
    input wire signed [7:0] x4, y4, x5, y5, x6, y6, x7, y7,
    output reg signed [15:0] A_x, A_y,
    output reg signed [15:0] B_x, B_y,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LATCH     = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] OUTPUT    = 3'd4;

    reg [2:0] state, next_state;

    // Internal registers for swimmer data
    reg signed [7:0] x_reg [0:7];
    reg signed [7:0] y_reg [0:7];
    reg [3:0] n_reg;

    // Sorting network registers
    reg signed [7:0] sorted_x [0:7];

    // Median calculation
    reg signed [15:0] median_x;

    // Cycle counter for bounded computation
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 5'd0;
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
                    next_state = LATCH;
                end
            end
            LATCH: begin
                next_state = SORT;
            end
            SORT: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                next_state = OUTPUT;
            end
            OUTPUT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Latch inputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n_reg <= 4'd0;
            for (integer i = 0; i < 8; i = i + 1) begin
                x_reg[i] <= 8'd0;
                y_reg[i] <= 8'd0;
            end
        end else if (state == LATCH) begin
            n_reg <= n;
            x_reg[0] <= x0; y_reg[0] <= y0;
            x_reg[1] <= x1; y_reg[1] <= y1;
            x_reg[2] <= x2; y_reg[2] <= y2;
            x_reg[3] <= x3; y_reg[3] <= y3;
            x_reg[4] <= x4; y_reg[4] <= y4;
            x_reg[5] <= x5; y_reg[5] <= y5;
            x_reg[6] <= x6; y_reg[6] <= y6;
            x_reg[7] <= x7; y_reg[7] <= y7;
        end
    end

    // Sorting network (bitonic sort for 8 elements)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 8; i = i + 1) begin
                sorted_x[i] <= 8'd0;
            end
            cycle_count <= 5'd0;
        end else if (state == SORT) begin
            cycle_count <= cycle_count + 5'd1;

            // Initialize sorted_x with x_reg
            if (cycle_count == 5'd1) begin
                for (integer i = 0; i < 8; i = i + 1) begin
                    sorted_x[i] <= x_reg[i];
                end
            end

            // Bitonic sort stages
            // Stage 1: Sort pairs
            if (cycle_count == 5'd2) begin
                for (integer i = 0; i < 8; i = i + 2) begin
                    if (sorted_x[i] > sorted_x[i+1]) begin
                        sorted_x[i] <= sorted_x[i+1];
                        sorted_x[i+1] <= x_reg[i];
                    end
                end
            end

            // Stage 2: Merge pairs into 4-element sorted sequences
            if (cycle_count == 5'd3) begin
                for (integer i = 0; i < 8; i = i + 4) begin
                    if (sorted_x[i] > sorted_x[i+2]) begin
                        sorted_x[i] <= sorted_x[i+2];
                        sorted_x[i+2] <= x_reg[i];
                    end
                    if (sorted_x[i+1] > sorted_x[i+3]) begin
                        sorted_x[i+1] <= sorted_x[i+3];
                        sorted_x[i+3] <= x_reg[i+1];
                    end
                end
            end

            // Stage 3: Merge 4-element sequences
            if (cycle_count == 5'd4) begin
                for (integer i = 0; i < 8; i = i + 2) begin
                    if (sorted_x[i] > sorted_x[i+1]) begin
                        sorted_x[i] <= sorted_x[i+1];
                        sorted_x[i+1] <= x_reg[i];
                    end
                end
            end

            // Stage 4: Final merge
            if (cycle_count == 5'd5) begin
                for (integer i = 0; i < 4; i = i + 1) begin
                    if (sorted_x[i] > sorted_x[i+4]) begin
                        sorted_x[i] <= sorted_x[i+4];
                        sorted_x[i+4] <= x_reg[i];
                    end
                end
            end

            // Stage 5: Final sort
            if (cycle_count == 5'd6) begin
                for (integer i = 0; i < 8; i = i + 2) begin
                    if (sorted_x[i] > sorted_x[i+1]) begin
                        sorted_x[i] <= sorted_x[i+1];
                        sorted_x[i+1] <= x_reg[i];
                    end
                end
            end
        end
    end

    // Median calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            median_x <= 16'd0;
        end else if (state == COMPUTE) begin
            case (n_reg)
                4'd1: median_x <= sorted_x[0];
                4'd2: median_x <= (sorted_x[0] + sorted_x[1]) / 2;
                4'd3: median_x <= sorted_x[1];
                4'd4: median_x <= (sorted_x[1] + sorted_x[2]) / 2;
                4'd5: median_x <= sorted_x[2];
                4'd6: median_x <= (sorted_x[2] + sorted_x[3]) / 2;
                4'd7: median_x <= sorted_x[3];
                4'd8: median_x <= (sorted_x[3] + sorted_x[4]) / 2;
                default: median_x <= 16'd0;
            endcase
        end
    end

    // Output calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A_x <= 16'd0; A_y <= 16'd0;
            B_x <= 16'd0; B_y <= 16'd0;
            done <= 1'b0;
        end else if (state == OUTPUT) begin
            A_x <= median_x - 16'd100;
            A_y <= 16'd0;
            B_x <= median_x + 16'd100;
            B_y <= 16'd0;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule