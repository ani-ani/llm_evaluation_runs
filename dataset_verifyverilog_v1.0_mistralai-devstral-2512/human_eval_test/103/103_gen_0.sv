module average_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [7:0] m,
    output reg [7:0] result,
    output reg valid,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] CHECK   = 3'd1;
    localparam [2:0] SUMMING = 3'd2;
    localparam [2:0] CALC    = 3'd3;
    localparam [2:0] DONE    = 3'd4;
    localparam [2:0] ERROR   = 3'd5;

    reg [2:0] state, next_state;
    reg [15:0] sum;
    reg [8:0] count;
    reg [7:0] current;
    reg [7:0] average;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd512;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            valid <= 1'b0;
            error <= 1'b0;
            sum <= 16'd0;
            count <= 9'd0;
            current <= 8'd0;
            average <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECK;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK: begin
                    if (n > m) begin
                        next_state <= ERROR;
                    end else begin
                        sum <= 16'd0;
                        current <= n;
                        count <= m - n + 1;
                        next_state <= SUMMING;
                    end
                end

                SUMMING: begin
                    cycle_count <= cycle_count + 8'd1;
                    sum <= sum + current;
                    if (current == m) begin
                        next_state <= CALC;
                    end else begin
                        current <= current + 8'd1;
                        next_state <= SUMMING;
                    end
                end

                CALC: begin
                    // Compute average with rounding: (sum + count/2) / count
                    average <= (sum + (count >> 1)) / count;
                    result <= average;
                    next_state <= DONE;
                end

                DONE: begin
                    valid <= 1'b1;
                    next_state <= IDLE;
                end

                ERROR: begin
                    error <= 1'b1;
                    result <= 8'd0;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule