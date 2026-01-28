module baltic_drain (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] grid_data,
    input wire [1:0] drain_row,
    input wire [1:0] drain_col,
    output reg [15:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC_LOOP = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] idx;
    reg signed [7:0] grid_reg [0:15];
    reg signed [7:0] drain_alt;
    reg [15:0] sum_reg;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            idx <= 4'd0;
            sum_reg <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                grid_reg[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            grid_reg[i] <= grid_data[8*i +: 8];
                        end
                        drain_alt <= grid_data[8*(drain_row * 4 + drain_col) +: 8];
                        sum_reg <= 16'd0;
                        idx <= 4'd0;
                        state <= CALC_LOOP;
                    end
                end

                CALC_LOOP: begin
                    if (idx < 4'd16) begin
                        if (grid_reg[idx] < 8'd0) begin
                            if (-grid_reg[idx] < -drain_alt)
                                sum_reg <= sum_reg + (-grid_reg[idx]);
                            else
                                sum_reg <= sum_reg + (-drain_alt);
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        result <= sum_reg;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule