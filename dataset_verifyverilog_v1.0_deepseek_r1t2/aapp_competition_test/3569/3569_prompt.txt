module max_hit_calculator #(parameter N=8) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] start_angles [0:N-1],
    input wire [31:0] end_angles   [0:N-1],
    input wire [N-1:0] valid,
    output reg [7:0] max_overlap,
    output reg done
);

// Constants
localparam TWO_PI = 32'd6283185; // 2 * pi * 1e6 (micro-radians)

// State definitions
localparam IDLE = 3'b000;
localparam SPLIT = 3'b001;
localparam GEN_EVENTS = 3'b010;
localparam SORT = 3'b011;
localparam SWEEP = 3'b100;
localparam DONE = 3'b101;

// Internal registers
reg [2:0] state;
reg [7:0] idx;          // general index
reg [7:0] idx2;         // second index for sorting
reg [7:0] interval_cnt; // number of intervals after splitting
reg [7:0] event_cnt;    // number of events

// Interval buffers: up to 2*N intervals
reg [31:0] starts [0:2*N-1];
reg [31:0] ends   [0:2*N-1];

// Event buffers: each event is 33 bits: [32:1] angle, [0] type (1=start, 0=end)
reg [32:0] events [0:4*N-1];

// Current count and max count
reg [7:0] count;
reg [7:0] max_count;

// Helper task to reset internal state
task reset_internal;
begin
    interval_cnt <= 0;
    event_cnt <= 0;
    count <= 0;
    max_count <= 0;
    idx <= 0;
    idx2 <= 0;
end
endtask

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        max_overlap <= 0;
        reset_internal;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    state <= SPLIT;
                    reset_internal;
                end
            end

            SPLIT: begin
                if (idx < N) begin
                    if (valid[idx]) begin
                        // Check if wrap-around
                        if (start_angles[idx] <= end_angles[idx]) begin
                            // No wrap
                            starts[interval_cnt] <= start_angles[idx];
                            ends[interval_cnt] <= end_angles[idx];
                            interval_cnt <= interval_cnt + 1;
                        end else begin
                            // Wrap: split into two intervals
                            // First: start to TWO_PI
                            starts[interval_cnt] <= start_angles[idx];
                            ends[interval_cnt] <= TWO_PI;
                            interval_cnt <= interval_cnt + 1;
                            // Second: 0 to end
                            starts[interval_cnt] <= 0;
                            ends[interval_cnt] <= end_angles[idx];
                            interval_cnt <= interval_cnt + 1;
                        end
                    end
                    idx <= idx + 1;
                end else begin
                    idx <= 0;
                    state <= GEN_EVENTS;
                end
            end

            GEN_EVENTS: begin
                if (idx < interval_cnt) begin
                    // Create start event
                    events[event_cnt] <= {starts[idx], 1'b1};
                    event_cnt <= event_cnt + 1;
                    // Create end event
                    events[event_cnt] <= {ends[idx], 1'b0};
                    event_cnt <= event_cnt + 1;
                    idx <= idx + 1;
                end else begin
                    // If no events, go directly to DONE
                    if (event_cnt == 0) begin
                        state <= DONE;
                    end else begin
                        state <= SORT;
                        idx <= 0;
                        idx2 <= 0;
                    end
                end
            end

            SORT: begin
                // Bubble sort: one swap per clock cycle
                if (idx < event_cnt - 1) begin
                    if (idx2 < event_cnt - idx - 1) begin
                        // Compare events[idx2] and events[idx2+1]
                        if (events[idx2][32:1] > events[idx2+1][32:1] || 
                            (events[idx2][32:1] == events[idx2+1][32:1] && events[idx2][0] > events[idx2+1][0])) begin
                            // Swap
                            events[idx2] <= events[idx2+1];
                            events[idx2+1] <= events[idx2];
                        end
                        idx2 <= idx2 + 1;
                    end else begin
                        // Next pass
                        idx <= idx + 1;
                        idx2 <= 0;
                    end
                end else begin
                    // Sorting done
                    state <= SWEEP;
                    idx <= 0;
                    count <= 0;
                    max_count <= 0;
                end
            end

            SWEEP: begin
                if (idx < event_cnt) begin
                    // Update count
                    if (events[idx][0] == 1'b1) begin // start event
                        count <= count + 1;
                        if (count + 1 > max_count) begin
                            max_count <= count + 1;
                        end
                    end else begin // end event
                        count <= count - 1;
                    end
                    idx <= idx + 1;
                end else begin
                    state <= DONE;
                end
            end

            DONE: begin
                max_overlap <= max_count;
                done <= 1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule