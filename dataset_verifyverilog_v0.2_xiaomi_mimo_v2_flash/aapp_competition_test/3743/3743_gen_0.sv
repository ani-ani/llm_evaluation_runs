module aesthetic_path_solver(
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    output reg [31:0] result,
    output reg done
);

    reg [31:0] n_reg;
    reg [31:0] orig_n;
    reg [31:0] d;

    localparam IDLE = 3'd0;
    localparam CHECK_1 = 3'd1;
    localparam HANDLE_POW2 = 3'd2;
    localparam CHECK_ODD = 3'd3;
    localparam VERIFY_POWER = 3'd4;
    localparam ITERATE = 3'd5;
    localparam DONE = 3'd6;

    reg [2:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        orig_n <= n;
                        d <= 32'd3;
                        state <= CHECK_1;
                    end
                end

                CHECK_1: begin
                    if (n_reg == 32'd1) begin
                        result <= 32'd1;
                        state <= DONE;
                    end else if (n_reg[0] == 1'b0) begin
                        state <= HANDLE_POW2;
                    end else begin
                        state <= CHECK_ODD;
                    end
                end

                HANDLE_POW2: begin
                    if (n_reg[0] == 1'b0 && n_reg > 1) begin
                        n_reg <= n_reg >> 1;
                    end else begin
                        if (n_reg == 32'd1) result <= 32'd2;
                        else result <= 32'd1;
                        state <= DONE;
                    end
                end

                CHECK_ODD: begin
                    d <= d + 32'd2;
                end

                VERIFY_POWER: begin
                    n_reg <= n_reg / d;
                end

                ITERATE: begin
                    if (n_reg % d == 0 && n_reg > 1) begin
                        n_reg <= n_reg / d;
                    end else begin
                        if (n_reg == 32'd1) result <= d;
                        else result <= 32'd1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    state <= IDLE;
                    done <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start) state = CHECK_1; else state = IDLE;
            end

            CHECK_1: begin
                if (n_reg == 32'd1) state = DONE;
                else if (n_reg[0] == 0) state = HANDLE_POW2;
                else state = CHECK_ODD;
            end

            HANDLE_POW2: begin
                if (n_reg[0] == 0 && n_reg > 1) state = HANDLE_POW2;
                else state = DONE;
            end

            CHECK_ODD: begin
                if ({32'd0, d} * {32'd0, d} > {32'd0, n_reg}) begin
                    state = DONE;
                end else if ((n_reg % d) == 0) begin
                    state = VERIFY_POWER;
                end else begin
                    state = CHECK_ODD;
                end
            end

            VERIFY_POWER: begin
                state = ITERATE;
            end

            ITERATE: begin
                if (n_reg % d == 0 && n_reg > 1) state = ITERATE;
                else state = DONE;
            end

            DONE: state = IDLE;
            default: state = IDLE;
        endcase
    end

    wire d_squared_gt_n;
    assign d_squared_gt_n = ({32'd0, d} * {32'd0, d} > {32'd0, n_reg});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled
        end else begin
            if (state == CHECK_ODD && d_squared_gt_n) begin
                result <= orig_n;
            end
        end
    end

endmodule