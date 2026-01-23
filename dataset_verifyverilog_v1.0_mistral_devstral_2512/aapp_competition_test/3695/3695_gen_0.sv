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

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PREPROCESS = 2'd1;
    localparam [1:0] SORT_EVENTS = 2'd2;
    localparam [1:0] SWEEP = 2'd3;
    localparam [1:0] DONE_STATE = 2'd4;

    reg [1:0] state;
    reg [2:0] i;
    reg [4:0] event_count;
    reg [7:0] events_time [0:15];
    reg events_is_end [0:15];
    reg [7:0] counter, max_count;
    reg [4:0] j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            event_count <= 5'd0;
            counter <= 8'd0;
            max_count <= 8'd0;
            i <= 3'd0;
            j <= 5'd0;
            k <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PREPROCESS;
                        i <= 3'd0;
                        event_count <= 5'd0;
                    end
                end

                PREPROCESS: begin
                    if (i < n) begin
                        if (T >= (i + 2)) begin
                            reg [7:0] m_val;
                            if (t_i[i] > (i + 1))
                                m_val = t_i[i] - i - 1;
                            else
                                m_val = 8'd0;
                            reg [7:0] M_val = T - i - 2;
                            if (m_val <= M_val) begin
                                events_time[event_count] <= m_val;
                                events_is_end[event_count] <= 1'b0;
                                events_time[event_count + 1] <= M_val;
                                events_is_end[event_count + 1] <= 1'b1;
                                event_count <= event_count + 2;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        if (event_count > 0) begin
                            state <= SORT_EVENTS;
                            j <= 5'd0;
                            k <= 5'd0;
                        end else begin
                            state <= DONE_STATE;
                            result <= 4'd0;
                        end
                    end
                end

                SORT_EVENTS: begin
                    if (j < event_count - 1) begin
                        if (k < event_count - j - 1) begin
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
                            k <= k + 1;
                        end else begin
                            k <= 5'd0;
                            j <= j + 1;
                        end
                    end else begin
                        state <= SWEEP;
                        i <= 3'd0;
                        counter <= 8'd0;
                        max_count <= 8'd0;
                    end
                end

                SWEEP: begin
                    if (i < event_count) begin
                        if (events_is_end[i] == 1'b0) begin
                            counter <= counter + 1;
                            if (counter + 1 > max_count)
                                max_count <= counter + 1;
                        end else begin
                            counter <= counter - 1;
                        end
                        i <= i + 1;
                    end else begin
                        state <= DONE_STATE;
                        result <= max_count;
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