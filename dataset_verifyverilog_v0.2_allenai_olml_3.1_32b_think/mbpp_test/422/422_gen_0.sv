module average_of_cubes (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [31:0] result,
    output reg done
);
// Registers
reg [2:0] state;
reg [3:0] i;
reg [31:0] sum;
reg [31:0] temp;
reg [31:0] result_reg;
reg done_reg;
localparam IDLE = 3'd0,
          CALC_SUM = 3'd1,
          DIVIDE = 3'd2,
          DONE_STATE = 3'd3;
always_comb begin
    reg [2:0] next_state = state; // default

    case (state)
        IDLE: begin
            if (start) begin
                next_state = CALC_SUM;
            end
        end
        CALC_SUM: begin
            if (i > n) begin
                next_state = DIVIDE;
            end
        end
        DIVIDE: begin
            next_state = DONE_STATE;
        end
        DONE_STATE: begin
            // do nothing, stay in DONE
        end
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= IDLE;
        i <= 4'd0;
        sum <= 32'd0;
        temp <= 32'd0;
        result_reg <= 32'd0;
        done_reg <= 1'b0;
    end else begin
        state <= next_state; // from comb block

        case (state)
            IDLE: begin
                if (start) begin
                    // Initialize for calculation
                    i <= 4'd1;
                    sum <= 32'd0;
                end
            end
            CALC_SUM: begin
                // Accumulate sum and increment i
                sum <= sum + (i * i * i);
                i <= i + 1;
            end
            DIVIDE: begin
                // Compute result
                temp <= sum << 16;
                result_reg <= temp / n;
            end
            DONE_STATE: begin
                done_reg <= 1'b1;
            end
        endcase
    end
end
assign result = result_reg;
assign done = done_reg;
endmodule
