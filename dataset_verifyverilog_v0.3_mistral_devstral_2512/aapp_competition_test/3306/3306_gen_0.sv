module phone_network(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] valid_detectors,
    input wire [7:0] pos_0, pos_1, pos_2, pos_3,
    input wire [7:0] pos_4, pos_5, pos_6, pos_7,
    input wire [31:0] count_0, count_1, count_2, count_3,
    input wire [31:0] count_4, count_5, count_6, count_7,
    output reg [31:0] result,
    output reg done
);

    reg [7:0] sorted_pos [0:7];
    reg [31:0] sorted_count [0:7];
    reg [2:0] n_detectors;
    reg [2:0] sort_idx, sort_limit;
    reg [31:0] temp_result;
    reg [2:0] calc_idx;
    reg [1:0] state;
    integer i;

    localparam IDLE = 2'b00;
    localparam SORT = 2'b01;
    localparam CALC = 2'b10;
    localparam DONE = 2'b11;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            n_detectors <= 3'd0;
            sort_idx <= 3'd0;
            sort_limit <= 3'd0;
            calc_idx <= 3'd0;
            temp_result <= 32'd0;
            for (i = 0; i < 8; i = i + 1) begin
                sorted_pos[i] <= 8'd0;
                sorted_count[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        sorted_pos[0] <= pos_0; sorted_count[0] <= count_0;
                        sorted_pos[1] <= pos_1; sorted_count[1] <= count_1;
                        sorted_pos[2] <= pos_2; sorted_count[2] <= count_2;
                        sorted_pos[3] <= pos_3; sorted_count[3] <= count_3;
                        sorted_pos[4] <= pos_4; sorted_count[4] <= count_4;
                        sorted_pos[5] <= pos_5; sorted_count[5] <= count_5;
                        sorted_pos[6] <= pos_6; sorted_count[6] <= count_6;
                        sorted_pos[7] <= pos_7; sorted_count[7] <= count_7;
                        n_detectors <= valid_detectors;
                        sort_idx <= 3'd0;
                        sort_limit <= valid_detectors - 3'd1;
                        state <= SORT;
                    end
                end
                
                SORT: begin
                    if (sort_idx < sort_limit) begin
                        if (sorted_pos[sort_idx] > sorted_pos[sort_idx + 1]) begin
                            sorted_pos[sort_idx] <= sorted_pos[sort_idx + 1];
                            sorted_pos[sort_idx + 1] <= sorted_pos[sort_idx];
                            sorted_count[sort_idx] <= sorted_count[sort_idx + 1];
                            sorted_count[sort_idx + 1] <= sorted_count[sort_idx];
                        end
                        sort_idx <= sort_idx + 3'd1;
                    end else begin
                        if (sort_limit > 3'd0) begin
                            sort_limit <= sort_limit - 3'd1;
                            sort_idx <= 3'd0;
                        end else begin
                            temp_result <= sorted_count[0];
                            calc_idx <= 3'd1;
                            state <= CALC;
                        end
                    end
                end
                
                CALC: begin
                    if (calc_idx < n_detectors) begin
                        if (sorted_count[calc_idx] > sorted_count[calc_idx - 1]) begin
                            temp_result <= temp_result + 
                                (sorted_count[calc_idx] - sorted_count[calc_idx - 1]);
                        end
                        calc_idx <= calc_idx + 3'd1;
                    end else begin
                        result <= temp_result;
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