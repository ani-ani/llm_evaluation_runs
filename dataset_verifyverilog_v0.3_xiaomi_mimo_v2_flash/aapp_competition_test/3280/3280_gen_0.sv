module tv_recorder(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [2:0] k,
    input [15:0] start_times [0:7],
    input [15:0] end_times [0:7],
    output reg [3:0] count,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] INIT = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE = 3'd4;
    localparam [2:0] BUSY = 3'd5;

    reg [2:0] state;
    reg [3:0] show_idx;
    reg [2:0] machine_idx;
    reg [15:0] machine_end [0:3];
    reg [15:0] sorted_start [0:7];
    reg [15:0] sorted_end [0:7];
    reg [15:0] temp_start [0:7];
    reg [15:0] temp_end [0:7];
    reg [2:0] sort_pass;
    reg [2:0] sort_i;
    reg [3:0] cycle_counter;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            done <= 1'b0;
            show_idx <= 4'd0;
            machine_idx <= 3'd0;
            sort_pass <= 3'd0;
            sort_i <= 3'd0;
            cycle_counter <= 4'd0;
            for (i = 0; i < 4; i = i + 1) begin
                machine_end[i] <= 16'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                sorted_start[i] <= 16'd0;
                sorted_end[i] <= 16'd0;
                temp_start[i] <= 16'd0;
                temp_end[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 4'd0;
                    if (start) begin
                        state <= SORT;
                        sort_pass <= 3'd0;
                        sort_i <= 3'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_start[i] <= start_times[i];
                            temp_end[i] <= end_times[i];
                        end
                    end
                end

                SORT: begin
                    if (sort_pass < 3'd2 && sort_i < 3'd7) begin
                        if (temp_end[sort_i] > temp_end[sort_i + 1]) begin
                            temp_start[sort_i] <= temp_start[sort_i + 1];
                            temp_start[sort_i + 1] <= temp_start[sort_i];
                            temp_end[sort_i] <= temp_end[sort_i + 1];
                            temp_end[sort_i + 1] <= temp_end[sort_i];
                        end
                        sort_i <= sort_i + 1'b1;
                    end else if (sort_pass < 3'd2) begin
                        sort_pass <= sort_pass + 1'b1;
                        sort_i <= 3'd0;
                    end else begin
                        for (i = 0; i < 8; i = i + 1) begin
                            sorted_start[i] <= temp_start[i];
                            sorted_end[i] <= temp_end[i];
                        end
                        state <= INIT;
                    end
                end

                INIT: begin
                    for (i = 0; i < 4; i = i + 1) begin
                        machine_end[i] <= 16'd0;
                    end
                    count <= 4'd0;
                    show_idx <= 4'd0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    if (show_idx < n && show_idx < 8'd8) begin
                        machine_idx <= 3'd0;
                        state <= BUSY;
                    end else begin
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                BUSY: begin
                    if (machine_idx < k && machine_idx < 3'd4) begin
                        if (machine_end[machine_idx] <= sorted_start[show_idx]) begin
                            machine_end[machine_idx] <= sorted_end[show_idx];
                            count <= count + 1'b1;
                            state <= COMPUTE;
                            show_idx <= show_idx + 1'b1;
                        end else begin
                            machine_idx <= machine_idx + 1'b1;
                        end
                    end else begin
                        state <= COMPUTE;
                        show_idx <= show_idx + 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule