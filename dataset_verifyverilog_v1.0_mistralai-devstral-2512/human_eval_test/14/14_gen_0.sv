module prefix_computer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] string_in [0:7],
    input wire [3:0] char_count,
    output reg [7:0] prefixes [0:7],
    output reg [3:0] valid_count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] prefix_pos;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd16;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            prefix_pos <= 4'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            valid_count <= 4'd0;
            // Initialize all prefixes to 0
            prefixes[0] <= 8'd0;
            prefixes[1] <= 8'd0;
            prefixes[2] <= 8'd0;
            prefixes[3] <= 8'd0;
            prefixes[4] <= 8'd0;
            prefixes[5] <= 8'd0;
            prefixes[6] <= 8'd0;
            prefixes[7] <= 8'd0;
        end else begin
            state <= next_state;
            if (state == COMPUTE) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                    prefix_pos = 4'd0;
                    cycle_count = 8'd0;
                    done = 1'b0;
                    valid_count = 4'd0;
                end
            end

            COMPUTE: begin
                if (prefix_pos < char_count) begin
                    // Compute current prefix length
                    prefixes[prefix_pos] = prefix_pos + 4'd1;
                    prefix_pos = prefix_pos + 4'd1;
                    valid_count = prefix_pos;
                end
                // Exit condition: either done with all prefixes or max cycles reached
                if ((prefix_pos >= char_count) || (cycle_count >= MAX_CYCLES - 8'd1)) begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule