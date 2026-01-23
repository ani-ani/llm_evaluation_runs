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
    output reg [1:0] result  // 00=legit, 01=insufficient, 10=tampered
);

reg [2:0] state;
reg [2:0] idx;
reg [7:0] prev_y;
reg [3:0] prev_m;
reg [16:0] prev_o;
reg [15:0] month_diff;
reg [23:0] dist;
reg [23:0] min_bound;
reg [23:0] max_bound;

localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam CALC = 3'd2;
localparam CHECK_TAMPER = 3'd3;
localparam CHECK_SERVICE = 3'd4;
localparam UPDATE = 3'd5;
localparam FINISH = 3'd6;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        result <= 2'b00;
        idx <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start && num_entries > 0) state <= INIT;
            end
            
            INIT: begin
                prev_y <= year[0];
                prev_m <= month[0];
                prev_o <= odo[0];
                idx <= 1;
                if (num_entries == 1) begin
                    result <= 2'b00;
                    done <= 1;
                    state <= FINISH;
                end else state <= CALC;
            end
            
            CALC: begin
                if (idx < num_entries) begin
                    month_diff <= (year[idx] - prev_y) * 12 + (month[idx] - prev_m);
                    if (odo[idx] >= prev_o) dist <= odo[idx] - prev_o;
                    else dist <= (100000 - prev_o) + odo[idx];
                    state <= CHECK_TAMPER;
                end else begin
                    result <= 2'b00;
                    done <= 1;
                    state <= FINISH;
                end
            end
            
            CHECK_TAMPER: begin
                if (month_diff == 0) begin
                    min_bound <= 0;
                    max_bound <= 20000;
                end else begin
                    min_bound <= (month_diff - 1) * 2000;
                    max_bound <= (month_diff + 1) * 20000;
                end
                if (dist < min_bound || dist > max_bound) begin
                    result <= 2'b10;
                    done <= 1;
                    state <= FINISH;
                end else state <= CHECK_SERVICE;
            end
            
            CHECK_SERVICE: begin
                if (month_diff > 12 || dist > 30000) begin
                    result <= 2'b01;
                    done <= 1;
                    state <= FINISH;
                end else state <= UPDATE;
            end
            
            UPDATE: begin
                prev_y <= year[idx];
                prev_m <= month[idx];
                prev_o <= odo[idx];
                idx <= idx + 1;
                state <= CALC;
            end
            
            FINISH: begin
                if (!start) begin
                    state <= IDLE;
                    done <= 0;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule