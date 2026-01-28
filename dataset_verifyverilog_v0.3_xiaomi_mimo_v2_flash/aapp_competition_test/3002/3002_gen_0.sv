module service_checker #(
    parameter MAX_ENTRIES = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [7:0] year [0:MAX_ENTRIES-1],
    input wire [3:0] month [0:MAX_ENTRIES-1],
    input wire [16:0] odo [0:MAX_ENTRIES-1],
    input wire [2:0] num_entries,
    
    output reg done,
    output reg [1:0] result
);

    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] INIT         = 3'd1;
    localparam [2:0] CALC         = 3'd2;
    localparam [2:0] CHECK_TAMPER = 3'd3;
    localparam [2:0] CHECK_SERVICE = 3'd4;
    localparam [2:0] UPDATE       = 3'd5;
    localparam [2:0] FINISH       = 3'd6;

    reg [2:0] state;
    reg [2:0] idx;
    reg [7:0] prev_y;
    reg [3:0] prev_m;
    reg [16:0] prev_o;
    reg [15:0] month_diff;
    reg [23:0] dist;
    reg [23:0] min_bound;
    reg [23:0] max_bound;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 2'b00;
            idx <= 3'd0;
            prev_y <= 8'd0;
            prev_m <= 4'd0;
            prev_o <= 17'd0;
            month_diff <= 16'd0;
            dist <= 24'd0;
            min_bound <= 24'd0;
            max_bound <= 24'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && num_entries > 3'd0) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    prev_y <= year[0];
                    prev_m <= month[0];
                    prev_o <= odo[0];
                    idx <= 3'd1;
                    if (num_entries == 3'd1) begin
                        result <= 2'b00;
                        done <= 1'b1;
                        state <= FINISH;
                    end else begin
                        state <= CALC;
                    end
                end

                CALC: begin
                    if (idx < num_entries) begin
                        month_diff <= (year[idx] - prev_y) * 16'd12 + (month[idx] - prev_m);
                        if (odo[idx] >= prev_o) begin
                            dist <= odo[idx] - prev_o;
                        end else begin
                            dist <= (17'd100000 - prev_o) + odo[idx];
                        end
                        state <= CHECK_TAMPER;
                    end else begin
                        result <= 2'b00;
                        done <= 1'b1;
                        state <= FINISH;
                    end
                end

                CHECK_TAMPER: begin
                    if (month_diff == 16'd0) begin
                        min_bound <= 24'd0;
                        max_bound <= 24'd20000;
                    end else begin
                        min_bound <= (month_diff - 16'd1) * 24'd2000;
                        max_bound <= (month_diff + 16'd1) * 24'd20000;
                    end
                    if (dist < min_bound || dist > max_bound) begin
                        result <= 2'b10;
                        done <= 1'b1;
                        state <= FINISH;
                    end else begin
                        state <= CHECK_SERVICE;
                    end
                end

                CHECK_SERVICE: begin
                    if (month_diff > 16'd12 || dist > 24'd30000) begin
                        result <= 2'b01;
                        done <= 1'b1;
                        state <= FINISH;
                    end else begin
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    prev_y <= year[idx];
                    prev_m <= month[idx];
                    prev_o <= odo[idx];
                    idx <= idx + 3'd1;
                    state <= CALC;
                end

                FINISH: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule