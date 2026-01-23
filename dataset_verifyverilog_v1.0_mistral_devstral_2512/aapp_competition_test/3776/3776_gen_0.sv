module BrokenClockFix(
    input clk,
    input rst_n,
    input start,
    input format,
    input [15:0] time_in,
    output reg [15:0] time_out,
    output reg done
);

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    localparam [5:0] MAX_HOURS_24 = 6'd23;
    localparam [5:0] MAX_HOURS_12 = 6'd12;
    localparam [5:0] MAX_MINUTES = 6'd59;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    reg [5:0] best_hour;
    reg [5:0] best_minute;
    reg [7:0] min_changes;

    reg [5:0] hour;
    reg [5:0] minute;
    reg [7:0] changes;

    reg [3:0] h1_in, h2_in, m1_in, m2_in;
    reg [3:0] h1_out, h2_out, m1_out, m2_out;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            time_out <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            best_hour <= 6'd0;
            best_minute <= 6'd0;
            min_changes <= 8'd0;
            hour <= 6'd0;
            minute <= 6'd0;
            changes <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        h1_in <= time_in[15:12];
                        h2_in <= time_in[11:8];
                        m1_in <= time_in[7:4];
                        m2_in <= time_in[3:0];
                        best_hour <= 6'd0;
                        best_minute <= 6'd0;
                        min_changes <= 8'd100;
                        hour <= 6'd0;
                        minute <= 6'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (format == 1'b0) begin
                        if (hour <= MAX_HOURS_24) begin
                            if (minute <= MAX_MINUTES) begin
                                h1_out <= hour[5:4];
                                h2_out <= hour[3:0];
                                m1_out <= minute[5:4];
                                m2_out <= minute[3:0];

                                changes <= 0;
                                if (h1_out != h1_in) changes <= changes + 8'd1;
                                if (h2_out != h2_in) changes <= changes + 8'd1;
                                if (m1_out != m1_in) changes <= changes + 8'd1;
                                if (m2_out != m2_in) changes <= changes + 8'd1;

                                if (changes < min_changes) begin
                                    min_changes <= changes;
                                    best_hour <= hour;
                                    best_minute <= minute;
                                end
                            end
                            minute <= minute + 6'd1;
                            if (minute > MAX_MINUTES) begin
                                minute <= 6'd0;
                                hour <= hour + 6'd1;
                            end
                        else begin
                            state <= FINISH;
                        end
                    end else begin
                        if (hour >= 6'd1 && hour <= MAX_HOURS_12) begin
                            if (minute <= MAX_MINUTES) begin
                                h1_out <= hour[5:4];
                                h2_out <= hour[3:0];
                                m1_out <= minute[5:4];
                                m2_out <= minute[3:0];

                                changes <= 0;
                                if (h1_out != h1_in) changes <= changes + 8'd1;
                                if (h2_out != h2_in) changes <= changes + 8'd1;
                                if (m1_out != m1_in) changes <= changes + 8'd1;
                                if (m2_out != m2_in) changes <= changes + 8'd1;

                                if (changes < min_changes) begin
                                    min_changes <= changes;
                                    best_hour <= hour;
                                    best_minute <= minute;
                                end
                            end
                            minute <= minute + 6'd1;
                            if (minute > MAX_MINUTES) begin
                                minute <= 6'd0;
                                hour <= hour + 6'd1;
                            end
                        else begin
                            state <= FINISH;
                        end
                    end

                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    time_out <= {best_hour[5:4], best_hour[3:0], best_minute[5:4], best_minute[3:0]};
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule