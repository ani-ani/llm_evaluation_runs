module tuple_to_dict (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuple_data [0:5],
    output reg [7:0] keys [0:2],
    output reg [7:0] values [0:2],
    output reg [2:0] valid_pairs,
    output reg done
);

// Parameters
localparam [1:0] MAX_PAIRS = 2'd3;
localparam [1:0] TUPLE_SIZE = 2'd6;
localparam [1:0] DATA_WIDTH = 2'd8;

// State definitions
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] FINISHED = 2'd2;

// Internal state
reg [1:0] state;
reg [1:0] pair_idx;
reg [3:0] cycle_count; // Prevent infinite loops
localparam [3:0] MAX_CYCLES = 4'd10;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        pair_idx <= 2'd0;
        valid_pairs <= 3'd0;
        done <= 1'b0;
        cycle_count <= 4'd0;
        keys[0] <= 8'd0;
        keys[1] <= 8'd0;
        keys[2] <= 8'd0;
        values[0] <= 8'd0;
        values[1] <= 8'd0;
        values[2] <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                pair_idx <= 2'd0;
                valid_pairs <= 3'd0;
                cycle_count <= 4'd0;
                if (start) begin
                    state <= COMPUTE;
                end
            end

            COMPUTE: begin
                cycle_count <= cycle_count + 4'd1;

                // Process adjacent pairs: tuple[0]=key, tuple[1]=val, tuple[2]=key, etc.
                if (pair_idx < MAX_PAIRS) begin
                    keys[pair_idx] <= tuple_data[pair_idx * 2];
                    values[pair_idx] <= tuple_data[pair_idx * 2 + 1];
                    pair_idx <= pair_idx + 2'd1;
                    valid_pairs <= pair_idx + 3'd1;

                    // Check if we just processed the last pair
                    if (pair_idx == MAX_PAIRS - 2'd1) begin
                        state <= FINISHED;
                    end
                end else begin
                    state <= FINISHED;
                end

                // Failsafe: move to finished if too many cycles
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FINISHED;
                end
            end

            FINISHED: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule