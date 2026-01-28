module dog_show (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] T,
    input [7:0] t_i [0:7],
    output reg [3:0] result,
    output reg done
);

    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] PREPROCESS   = 4'd1;
    localparam [3:0] SORT_EVENTS  = 4'd2;
    localparam [3:0] SWEEP        = 4'd3;
    localparam [3:0] DONE_STATE   = 4'd4;

    reg [3:0] state;
    reg [2:0] i;
    reg [4:0] event_count;
    reg [7:0] events_time [0:15];
    reg events_is_end [0:15];
    reg [3:0] j, k;
    reg [7:0] counter, max_count;
    reg [7:0] m_val, M_val;
    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            event_count <= 5'd0;
            counter <= 8'd0;
            max_count <= 8'd0;
            i <= 3'd0;
            j <= 4'd0;
            k <= 4'd0;
            m_val <= 8'd0;
            M_val <= 8'd0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                events_time[idx] <= 8'd0;
                events_is_end[idx] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PREPROCESS;
                        i <= 3'd0;
                        event_count <= 5'd0;
                        m_val <= 8'd0;
                        M_val <= 8'd0;
                    end
                end

                PREPROCESS: begin
                    if (i < n) begin
                        if (T >= (i + 2)) begin
                            if (t_i[i] > (i + 1)) begin
                                m_val <= t_i[i] - i - 1;
                            end else begin
                                m_val <= 8'd0;
                            end
                            M_val <= T - i - 2;
                            if ((t_i[i] > (i + 1) ? (t_i[i] - i - 1) : 8'd0) <= (T - i - 2)) begin
                                events_time[event_count] <= (t_i[i] > (i + 1) ? (t_i[i] - i - 1) : 8'd0);
                                events_is_end[event_count] <= 1'b0;
                                events_time[event_count + 1] <= (T - i - 2);
                                events_is_end[event_count + 1] <= 1'b1;
                                event_count <= event_count + 5'd2;
                            end
                        end
                        i <= i + 3'd1;
                    end else begin
                        if (event_count > 5'd0) begin
                            state <= SORT_EVENTS;
                            j <= 4'd0;
                            k <= 4'd0;
                        end else begin
                            state <= DONE_STATE;
                            result <= 4'd0;
                        end
                    end
                end

                SORT_EVENTS: begin
                    if (j < (event_count - 5'd1)) begin
                        if (k < (event_count - j - 5'd1)) begin
                            if (events_time[k] > events_time[k + 1]) begin
                                events_time[k] <= events_time[k + 1];
                                events_time[k + 1] <= events_time[k];
                                events_is_end[k] <= events_is_end[k + 1];
                                events_is_end[k + 1] <= events_is_end[k];
                            end else if (events_time[k] == events_time[k + 1]) begin
                                if (events_is_end[k] > events_is_end[k + 1]) begin
                                    events_time[k] <= events_time[k + 1];
                                    events_time[k + 1] <= events_time[k];
                                    events_is_end[k] <= events_is_end[k + 1];
                                    events_is_end[k + 1] <= events_is_end[k];
                                end
                            end
                            k <= k + 4'd1;
                        end else begin
                            k <= 4'd0;
                            j <= j + 4'd1;
                        end
                    end else begin
                        state <= SWEEP;
                        i <= 5'd0;
                        counter <= 8'd0;
                        max_count <= 8'd0;
                    end
                end

                SWEEP: begin
                    if (i < event_count) begin
                        if (events_is_end[i] == 1'b0) begin
                            counter <= counter + 8'd1;
                            if ((counter + 8'd1) > max_count) begin
                                max_count <= counter + 8'd1;
                            end
                        end else begin
                            counter <= counter - 8'd1;
                        end
                        i <= i + 5'd1;
                    end else begin
                        state <= DONE_STATE;
                        result <= max_count[3:0];
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule