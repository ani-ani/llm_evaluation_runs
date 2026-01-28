module earliest_train(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [4:0] M,
    input [3:0] train_X [0:15],
    input [15:0] train_S [0:15],
    input [15:0] train_T [0:15],
    input [15:0] train_L [0:15],
    output reg [15:0] result,
    output reg done
);

    localparam [15:0] INF = 16'd65535;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    reg [15:0] min_arrival [0:3];
    reg [4:0] current_station;
    reg [4:0] train_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_station <= 5'd0;
            train_index <= 5'd0;
            min_arrival[0] <= 16'd0;
            min_arrival[1] <= INF;
            min_arrival[2] <= INF;
            min_arrival[3] <= INF;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        current_station <= 5'd0;
                        train_index <= 5'd0;
                        min_arrival[0] <= 16'd0;
                        min_arrival[1] <= INF;
                        min_arrival[2] <= INF;
                        min_arrival[3] <= INF;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (current_station < N - 1) begin
                        if (train_index < M) begin
                            if (train_X[train_index] == current_station + 1 && train_X[train_index] + 1 == current_station + 2) begin
                                reg [15:0] scheduled_arrival;
                                reg [15:0] delayed_arrival;
                                scheduled_arrival = train_T[train_index];
                                delayed_arrival = train_T[train_index] + train_L[train_index];

                                if (delayed_arrival - scheduled_arrival >= 1800 && min_arrival[current_station] <= train_S[train_index]) begin
                                    if (delayed_arrival < min_arrival[current_station + 1]) begin
                                        min_arrival[current_station + 1] <= delayed_arrival;
                                    end
                                end
                            end
                            train_index <= train_index + 5'd1;
                        end else begin
                            train_index <= 5'd0;
                            current_station <= current_station + 5'd1;
                        end
                    end else begin
                        state <= FINISH;
                    end

                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (min_arrival[N - 1] == INF) begin
                        result <= 16'd0;
                    end else begin
                        result <= min_arrival[N - 1];
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule