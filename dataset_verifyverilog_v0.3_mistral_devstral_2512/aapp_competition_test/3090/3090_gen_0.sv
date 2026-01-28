module wireless_coverage (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] M,
    input wire [7:0] K,
    input wire [7:0] cost00, cost01, cost02, cost03,
    input wire [7:0] cost10, cost11, cost12, cost13,
    input wire [7:0] cost20, cost21, cost22, cost23,
    input wire [7:0] cost30, cost31, cost32, cost33,
    output reg [15:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] INIT = 3'b001;
    localparam [2:0] CALC = 3'b010;
    localparam [2:0] COMPARE = 3'b011;
    localparam [2:0] INCR = 3'b100;
    localparam [2:0] DONE = 3'b101;
    localparam [15:0] HUGE_PENALTY = 16'd10000;

    reg [2:0] state;
    reg [15:0] conf;
    reg [15:0] counter;
    reg [15:0] min_cost;
    reg [15:0] router_sum;
    reg [15:0] edge_sum;
    reg [15:0] total_cost;
    reg [3:0] row_idx, col_idx;
    reg phase;
    reg edge_type;
    reg [7:0] cost_reg [0:15];

    wire [3:0] pos;
    wire [15:0] valid_mask;

    always @(*) begin
        case (M)
            4'd1: pos = row_idx + col_idx;
            4'd2: pos = (row_idx << 1) + col_idx;
            4'd3: pos = (row_idx << 1) + row_idx + col_idx;
            4'd4: pos = (row_idx << 2) + col_idx;
            default: pos = 0;
        endcase
    end

    always @(*) begin
        case (N * M)
            1:  valid_mask = 16'h0001;
            2:  valid_mask = 16'h0003;
            3:  valid_mask = 16'h0007;
            4:  valid_mask = 16'h000F;
            5:  valid_mask = 16'h001F;
            6:  valid_mask = 16'h003F;
            7:  valid_mask = 16'h007F;
            8:  valid_mask = 16'h00FF;
            9:  valid_mask = 16'h01FF;
            10: valid_mask = 16'h03FF;
            11: valid_mask = 16'h07FF;
            12: valid_mask = 16'h0FFF;
            13: valid_mask = 16'h1FFF;
            14: valid_mask = 16'h3FFF;
            15: valid_mask = 16'h7FFF;
            16: valid_mask = 16'hFFFF;
            default: valid_mask = 16'hFFFF;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            counter <= 16'd0;
            min_cost <= 16'd0;
            conf <= 16'd0;
            router_sum <= 16'd0;
            edge_sum <= 16'd0;
            total_cost <= 16'd0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            phase <= 1'b0;
            edge_type <= 1'b0;
            cost_reg[0] <= 8'd0; cost_reg[1] <= 8'd0; cost_reg[2] <= 8'd0; cost_reg[3] <= 8'd0;
            cost_reg[4] <= 8'd0; cost_reg[5] <= 8'd0; cost_reg[6] <= 8'd0; cost_reg[7] <= 8'd0;
            cost_reg[8] <= 8'd0; cost_reg[9] <= 8'd0; cost_reg[10] <= 8'd0; cost_reg[11] <= 8'd0;
            cost_reg[12] <= 8'd0; cost_reg[13] <= 8'd0; cost_reg[14] <= 8'd0; cost_reg[15] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        cost_reg[0] <= cost00; cost_reg[1] <= cost01; cost_reg[2] <= cost02; cost_reg[3] <= cost03;
                        cost_reg[4] <= cost10; cost_reg[5] <= cost11; cost_reg[6] <= cost12; cost_reg[7] <= cost13;
                        cost_reg[8] <= cost20; cost_reg[9] <= cost21; cost_reg[10] <= cost22; cost_reg[11] <= cost23;
                        cost_reg[12] <= cost30; cost_reg[13] <= cost31; cost_reg[14] <= cost32; cost_reg[15] <= cost33;
                        counter <= 16'd0;
                        min_cost <= 16'hFFFF;
                        done <= 1'b0;
                        state <= INIT;
                    end
                end

                INIT: begin
                    conf <= counter;
                    router_sum <= 16'd0;
                    edge_sum <= 16'd0;
                    row_idx <= 4'd0;
                    col_idx <= 4'd0;
                    phase <= 1'b0;
                    edge_type <= 1'b0;
                    state <= CALC;
                end

                CALC: begin
                    if (phase == 1'b0) begin
                        if (row_idx < N) begin
                            if (col_idx < M) begin
                                if (conf[pos]) begin
                                    router_sum <= router_sum + cost_reg[pos];
                                end
                                col_idx <= col_idx + 4'd1;
                            end else begin
                                col_idx <= 4'd0;
                                row_idx <= row_idx + 4'd1;
                            end
                        end else begin
                            if (conf & ~valid_mask) begin
                                router_sum <= router_sum + HUGE_PENALTY;
                            end
                            phase <= 1'b1;
                            edge_type <= 1'b0;
                            row_idx <= 4'd0;
                            col_idx <= 4'd0;
                        end
                    end else begin
                        if (edge_type == 1'b0) begin
                            if (row_idx < N && col_idx < (M - 4'd1)) begin
                                if (conf[row_idx * M + col_idx] == conf[row_idx * M + col_idx + 4'd1]) begin
                                    edge_sum <= edge_sum + K;
                                end
                                col_idx <= col_idx + 4'd1;
                            end else begin
                                if (col_idx >= (M - 4'd1)) begin
                                    col_idx <= 4'd0;
                                    row_idx <= row_idx + 4'd1;
                                end
                                if (row_idx >= N) begin
                                    edge_type <= 1'b1;
                                    row_idx <= 4'd0;
                                    col_idx <= 4'd0;
                                end
                            end
                        end else begin
                            if (row_idx < (N - 4'd1) && col_idx < M) begin
                                if (conf[row_idx * M + col_idx] == conf[(row_idx + 4'd1) * M + col_idx]) begin
                                    edge_sum <= edge_sum + K;
                                end
                                col_idx <= col_idx + 4'd1;
                            end else begin
                                if (col_idx >= M) begin
                                    col_idx <= 4'd0;
                                    row_idx <= row_idx + 4'd1;
                                end
                                if (row_idx >= (N - 4'd1)) begin
                                    total_cost <= router_sum + edge_sum;
                                    state <= COMPARE;
                                end
                            end
                        end
                    end
                end

                COMPARE: begin
                    if (total_cost < min_cost) begin
                        min_cost <= total_cost;
                    end
                    state <= INCR;
                end

                INCR: begin
                    counter <= counter + 16'd1;
                    if (counter == 16'hFFFF) begin
                        state <= DONE;
                    end else begin
                        state <= INIT;
                    end
                end

                DONE: begin
                    result <= min_cost;
                    done <= 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule