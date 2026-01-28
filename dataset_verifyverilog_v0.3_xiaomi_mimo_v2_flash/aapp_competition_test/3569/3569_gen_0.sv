module max_hit_calculator #(parameter N=8) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] start_angles [0:N-1],
    input wire [31:0] end_angles [0:N-1],
    input wire [N-1:0] valid,
    output reg [7:0] max_overlap,
    output reg done
);

// Constants
localparam [31:0] TWO_PI = 32'd6283185; // 2 * pi * 1e6 (micro-radians)
localparam [7:0] MAX_INTERVALS = 8'd16; // 2 * N (N=8)
localparam [7:0] MAX_EVENTS = 8'd32; // 4 * N (N=8)

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] SPLIT = 4'd1;
localparam [3:0] GEN_EVENTS = 4'd2;
localparam [3:0] SORT = 4'd3;
localparam [3:0] SWEEP = 4'd4;
localparam [3:0] DONE = 4'd5;

// Internal registers
reg [3:0] state;
reg [7:0] idx;
reg [7:0] idx2;
reg [7:0] interval_cnt;
reg [7:0] event_cnt;
reg [7:0] count;
reg [7:0] max_count;

// Interval buffers
reg [31:0] starts [0:15];
reg [31:0] ends [0:15];

// Event buffers: 33 bits [32:1] angle, [0] type
reg [32:0] events [0:31];

// Helper task to reset internal state
task reset_internal;
begin
    interval_cnt <= 8'd0;
    event_cnt <= 8'd0;
    count <= 8'd0;
    max_count <= 8'd0;
    idx <= 8'd0;
    idx2 <= 8'd0;
end
endtask

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        max_overlap <= 8'd0;
        reset_internal;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= SPLIT;
                    reset_internal;
                end
            end

            SPLIT: begin
                if (idx < N[7:0]) begin
                    if (valid[idx]) begin
                        if (start_angles[idx] <= end_angles[idx]) begin
                            starts[interval_cnt] <= start_angles[idx];
                            ends[interval_cnt] <= end_angles[idx];
                            interval_cnt <= interval_cnt + 8'd1;
                        end else begin
                            starts[interval_cnt] <= start_angles[idx];
                            ends[interval_cnt] <= TWO_PI;
                            interval_cnt <= interval_cnt + 8'd1;
                            starts[interval_cnt + 8'd1] <= 32'd0;
                            ends[interval_cnt + 8'd1] <= end_angles[idx];
                            interval_cnt <= interval_cnt + 8'd2;
                        end
                    end
                    idx <= idx + 8'd1;
                end else begin
                    idx <= 8'd0;
                    state <= GEN_EVENTS;
                end
            end

            GEN_EVENTS: begin
                if (idx < interval_cnt) begin
                    events[event_cnt] <= {starts[idx], 1'b1};
                    event_cnt <= event_cnt + 8'd1;
                    events[event_cnt + 8'd1] <= {ends[idx], 1'b0};
                    event_cnt <= event_cnt + 8'd2;
                    idx <= idx + 8'd1;
                end else begin
                    if (event_cnt == 8'd0) begin
                        state <= DONE;
                    end else begin
                        state <= SORT;
                        idx <= 8'd0;
                        idx2 <= 8'd0;
                    end
                end
            end

            SORT: begin
                if (idx < event_cnt - 8'd1) begin
                    if (idx2 < event_cnt - idx - 8'd1) begin
                        if (events[idx2][32:1] > events[idx2 + 8'd1][32:1] || 
                            (events[idx2][32:1] == events[idx2 + 8'd1][32:1] && events[idx2][0] > events[idx2 + 8'd1][0])) begin
                            events[idx2] <= events[idx2 + 8'd1];
                            events[idx2 + 8'd1] <= events[idx2];
                        end
                        idx2 <= idx2 + 8'd1;
                    end else begin
                        idx <= idx + 8'd1;
                        idx2 <= 8'd0;
                    end
                end else begin
                    state <= SWEEP;
                    idx <= 8'd0;
                    count <= 8'd0;
                    max_count <= 8'd0;
                end
            end

            SWEEP: begin
                if (idx < event_cnt) begin
                    if (events[idx][0] == 1'b1) begin
                        count <= count + 8'd1;
                        if (count + 8'd1 > max_count) begin
                            max_count <= count + 8'd1;
                        end
                    end else begin
                        count <= count - 8'd1;
                    end
                    idx <= idx + 8'd1;
                end else begin
                    state <= DONE;
                end
            end

            DONE: begin
                max_overlap <= max_count;
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule