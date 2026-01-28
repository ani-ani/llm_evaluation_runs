module nonagonal(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_MUL1 = 3'd1;
    localparam [2:0] STATE_MUL2 = 3'd2;
    localparam [2:0] STATE_DIV = 3'd3;
    localparam [2:0] STATE_DONE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [31:0] temp1;
    reg [31:0] temp2;
    reg [31:0] temp3;
    reg [7:0] n_reg;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            result <= 16'd0;
            done <= 1'b0;
            temp1 <= 32'd0;
            temp2 <= 32'd0;
            temp3 <= 32'd0;
            n_reg <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            STATE_IDLE: begin
                if (start)
                    next_state = STATE_MUL1;
                else
                    next_state = STATE_IDLE;
            end
            STATE_MUL1: next_state = STATE_MUL2;
            STATE_MUL2: next_state = STATE_DIV;
            STATE_DIV: next_state = STATE_DONE;
            STATE_DONE: next_state = STATE_IDLE;
            default: next_state = STATE_IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n_reg <= 8'd0;
            temp1 <= 32'd0;
            temp2 <= 32'd0;
            temp3 <= 32'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        n_reg <= n;
                        done <= 1'b0;
                    end
                end
                STATE_MUL1: temp1 <= 32'd7 * n_reg;
                STATE_MUL2: temp2 <= (temp1 - 32'd5) * n_reg;
                STATE_DIV: temp3 <= temp2 >> 1;
                STATE_DONE: begin
                    result <= temp3[15:0];
                    done <= 1'b1;
                end
                default: begin
                    n_reg <= 8'd0;
                    temp1 <= 32'd0;
                    temp2 <= 32'd0;
                    temp3 <= 32'd0;
                end
            endcase
        end
    end

endmodule