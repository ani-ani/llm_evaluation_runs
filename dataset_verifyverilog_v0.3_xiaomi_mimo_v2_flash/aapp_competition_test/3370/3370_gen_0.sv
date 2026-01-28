module eagleton_tallest (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire signed [31:0] k,
    input wire signed [31:0] h0,
    input wire signed [31:0] h1,
    input wire signed [31:0] h2,
    input wire signed [31:0] h3,
    output reg signed [31:0] result,
    output reg done
);

    // Fixed-point division by 2 (arithmetic shift right)
    function signed [31:0] div2;
        input signed [31:0] x;
        begin
            div2 = {x[31], x[31:1]};
        end
    endfunction

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] START_SCAN    = 4'd1;
    localparam [3:0] CHECK_HOUSE   = 4'd2;
    localparam [3:0] UPDATE_HOUSE  = 4'd3;
    localparam [3:0] NEXT_HOUSE    = 4'd4;
    localparam [3:0] SCAN_DONE     = 4'd5;
    localparam [3:0] MAX_COMPUTE   = 4'd6;
    localparam [3:0] OUTPUT_STATE  = 4'd7;

    reg [3:0] state;
    reg [3:0] i;                     // 0-indexed house counter
    reg signed [31:0] heights [0:3]; // Current heights array
    reg changed;                     // Update flag
    reg [9:0] iteration_counter;     // Max 1000 scans
    reg signed [31:0] left;
    reg signed [31:0] right;
    reg signed [31:0] target;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'sd0;
            i <= 4'd0;
            changed <= 1'b0;
            iteration_counter <= 10'd0;
            heights[0] <= 32'sd0;
            heights[1] <= 32'sd0;
            heights[2] <= 32'sd0;
            heights[3] <= 32'sd0;
            left <= 32'sd0;
            right <= 32'sd0;
            target <= 32'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load initial heights based on N
                        if (N >= 4'd1) heights[0] <= h0;
                        else heights[0] <= 32'sd0;
                        if (N >= 4'd2) heights[1] <= h1;
                        else heights[1] <= 32'sd0;
                        if (N >= 4'd3) heights[2] <= h2;
                        else heights[2] <= 32'sd0;
                        if (N >= 4'd4) heights[3] <= h3;
                        else heights[3] <= 32'sd0;
                        i <= 4'd0;
                        changed <= 1'b0;
                        iteration_counter <= 10'd0;
                        state <= START_SCAN;
                    end
                end

                START_SCAN: begin
                    i <= 4'd0;
                    changed <= 1'b0;
                    state <= CHECK_HOUSE;
                end

                CHECK_HOUSE: begin
                    // Determine left neighbor
                    if (i == 4'd0) begin
                        left <= 32'sd0;
                    end else begin
                        left <= heights[i-1];
                    end
                    // Determine right neighbor
                    if (i == N-1) begin
                        right <= 32'sd0;
                    end else begin
                        right <= heights[i+1];
                    end
                    state <= UPDATE_HOUSE;
                end

                UPDATE_HOUSE: begin
                    target <= div2(left + right) + k;
                    if (heights[i] < target) begin
                        heights[i] <= target;
                        changed <= 1'b1;
                    end
                    state <= NEXT_HOUSE;
                end

                NEXT_HOUSE: begin
                    if (i < N-1) begin
                        i <= i + 4'd1;
                        state <= CHECK_HOUSE;
                    end else begin
                        state <= SCAN_DONE;
                    end
                end

                SCAN_DONE: begin
                    if (changed) begin
                        iteration_counter <= iteration_counter + 10'd1;
                        if (iteration_counter < 10'd1000) begin
                            state <= START_SCAN;
                        end else begin
                            state <= MAX_COMPUTE; // Timeout
                        end
                    end else begin
                        state <= MAX_COMPUTE; // Converged
                    end
                end

                MAX_COMPUTE: begin
                    // Find maximum height among N houses
                    result <= heights[0];
                    if (N > 4'd1 && heights[1] > result) result <= heights[1];
                    if (N > 4'd2 && heights[2] > result) result <= heights[2];
                    if (N > 4'd3 && heights[3] > result) result <= heights[3];
                    state <= OUTPUT_STATE;
                end

                OUTPUT_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule