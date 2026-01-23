module min_cost(
    input clk,
    input rst_n,
    input start,
    input [15:0] a,
    input [31:0] x,
    input [31:0] y,
    output reg [39:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] TRAVERSE  = 2'd1;
    localparam [1:0] COMPUTE   = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    reg [1:0] state, next_state;
    reg [4:0] idx;
    reg [3:0] groups;
    reg prev_bit;
    reg [31:0] min_val;
    reg [3:0] add_count;
    reg [39:0] accumulator;
    reg [39:0] result_reg;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 40'd0;
        end else begin
            state <= next_state;
            done <= (state == FINISH);
            result <= result_reg;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:     if (start) next_state = TRAVERSE;
            TRAVERSE: if (idx == 5'd16) next_state = (groups == 4'd0) ? FINISH : COMPUTE;
            COMPUTE:  if (add_count == 4'd0) next_state = FINISH;
            FINISH:   if (!start) next_state = IDLE;
            default:  next_state = IDLE;
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx <= 5'd0;
            groups <= 4'd0;
            prev_bit <= 1'b1;
            min_val <= 32'd0;
            add_count <= 4'd0;
            accumulator <= 40'd0;
            result_reg <= 40'd0;
        end else begin
            case (state)
                IDLE: begin
                    idx <= 5'd0;
                    groups <= 4'd0;
                    prev_bit <= 1'b1;
                    result_reg <= 40'd0;
                    if (start) begin
                        accumulator <= 40'd0;
                    end
                end

                TRAVERSE: begin
                    if (idx < 5'd16) begin
                        if (a[idx] == 1'b0 && prev_bit == 1'b1) begin
                            groups <= groups + 4'd1;
                        end
                        prev_bit <= a[idx];
                        idx <= idx + 5'd1;
                    end else if (groups > 4'd0) begin
                        min_val <= (x < y) ? x : y;
                        add_count <= groups - 4'd1;
                    end
                end

                COMPUTE: begin
                    if (add_count > 4'd0) begin
                        accumulator <= accumulator + {8'd0, min_val};
                        add_count <= add_count - 4'd1;
                    end
                end

                FINISH: begin
                    if (groups == 4'd0) begin
                        result_reg <= {8'd0, y};
                    end else begin
                        result_reg <= accumulator + {8'd0, y};
                    end
                end
            endcase
        end
    end
endmodule