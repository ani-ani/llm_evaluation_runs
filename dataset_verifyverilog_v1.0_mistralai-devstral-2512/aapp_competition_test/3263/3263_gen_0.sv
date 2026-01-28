module FluttershyService(
    input clk,
    input rst_n,
    input start,
    input [3:0] P_i,
    input [3:0] R_i,
    input [3:0] cust_type [0:15],
    input [15:0] cust_time [0:15],
    input [3:0] num_cust,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;
    reg [15:0] current_time;
    reg [3:0] current_clothing;
    reg [3:0] i;
    reg [15:0] served;
    reg [15:0] temp_time;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_time <= 16'd0;
            current_clothing <= 4'd0;
            i <= 4'd0;
            served <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                current_time = 16'd0;
                current_clothing = 4'd0;
                i = 4'd0;
                served = 16'd0;
                next_state = PROCESS;
            end

            PROCESS: begin
                if (i < num_cust) begin
                    temp_time = current_time;
                    if (cust_time[i] >= temp_time) begin
                        if (cust_type[i] != current_clothing) begin
                            if (current_clothing != 4'd0) begin
                                temp_time = temp_time + R_i[current_clothing - 1'b1];
                            end
                            temp_time = temp_time + P_i[cust_type[i] - 1'b1];
                        end
                        if (temp_time <= cust_time[i]) begin
                            current_time = cust_time[i];
                            served = served + 16'd1;
                        end else begin
                            current_time = temp_time;
                        end
                        current_clothing = cust_type[i];
                    end
                    i = i + 4'd1;
                end else begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                result = served;
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule