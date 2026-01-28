module swap_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str1,
    input wire [7:0] str2,
    output reg [3:0] result,
    output reg error,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPARE   = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] bit_counter;
    reg [3:0] mismatch_count;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_counter <= 4'd0;
            mismatch_count <= 4'd0;
            cycle_count <= 4'd0;
            result <= 4'd0;
            error <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and datapath logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPARE;
                    bit_counter = 4'd0;
                    mismatch_count = 4'd0;
                    cycle_count = 4'd0;
                    done = 1'b0;
                end
            end

            COMPARE: begin
                // Compare current bit
                if (str1[bit_counter] != str2[bit_counter]) begin
                    mismatch_count = mismatch_count + 4'd1;
                end

                // Move to next bit or next state
                if (bit_counter == 4'd7) begin
                    next_state = CALCULATE;
                end else begin
                    bit_counter = bit_counter + 4'd1;
                end
            end

            CALCULATE: begin
                // Check if mismatch count is odd
                if (mismatch_count[0]) begin
                    error = 1'b1;
                    result = 4'd0;
                end else begin
                    error = 1'b0;
                    result = mismatch_count >> 1;
                end
                next_state = FINISH;
            end

            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 4'd0;
        end else if (state != IDLE) begin
            if (cycle_count == MAX_CYCLES) begin
                cycle_count <= 4'd0;
                next_state = IDLE;
            end else begin
                cycle_count <= cycle_count + 4'd1;
            end
        end
    end

endmodule