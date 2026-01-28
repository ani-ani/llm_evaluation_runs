module QuoteMaxNesting(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] a_i [0:14],
    output reg done,
    output reg [7:0] result_k,
    output reg no_quot
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] min_val;
    reg [7:0] next_min_val;
    reg [3:0] idx;
    reg [3:0] next_idx;
    reg [7:0] min_pair;
    reg [7:0] min_outer;
    reg [7:0] next_result_k;
    reg next_no_quot;
    reg calc_done;
    reg next_calc_done;
    reg [7:0] temp_a_i;

    // Combinational logic for min computation
    always @(*) begin
        // Default values
        next_state = state;
        next_min_val = min_val;
        next_idx = idx;
        next_result_k = result_k;
        next_no_quot = no_quot;
        next_calc_done = calc_done;
        min_pair = 8'd255;
        min_outer = 8'd255;
        temp_a_i = 8'd0;

        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = CALC;
                    next_idx = 4'd0;
                    next_min_val = 8'd255;
                    next_calc_done = 1'b0;
                    next_result_k = 8'd0;
                    next_no_quot = 1'b0;
                end
            end

            CALC: begin
                done = 1'b0;
                if (n == 4'd0) begin
                    next_state = DONE;
                    next_calc_done = 1'b1;
                    next_no_quot = 1'b1;
                    next_result_k = 8'd0;
                end else if (idx < n) begin
                    // Get current value
                    temp_a_i = a_i[idx];
                    
                    // Check for zero
                    if (temp_a_i == 8'd0) begin
                        next_state = DONE;
                        next_calc_done = 1'b1;
                        next_no_quot = 1'b1;
                        next_result_k = 8'd0;
                    end else begin
                        // Compare with previous value
                        if (idx > 4'd0) begin
                            // min_pair = min(temp_a_i, a_i[idx-1])
                            min_pair = (temp_a_i < a_i[idx-1]) ? temp_a_i : a_i[idx-1];
                            // Update min_val
                            if (min_pair < next_min_val) begin
                                next_min_val = min_pair;
                            end
                        end
                        
                        // Update idx
                        next_idx = idx + 4'd1;
                    end
                end else begin
                    // Calculate outer min: min(a[0], a[n-1])
                    if (a_i[0] < a_i[n-1]) begin
                        min_outer = a_i[0];
                    end else begin
                        min_outer = a_i[n-1];
                    end
                    
                    // Final min
                    if (min_outer < next_min_val) begin
                        next_min_val = min_outer;
                    end
                    
                    next_state = DONE;
                    next_calc_done = 1'b1;
                    next_no_quot = 1'b0;
                    next_result_k = next_min_val;
                end
            end

            DONE: begin
                done = 1'b1;
                // Stay in DONE until next start
                if (start) begin
                    next_state = CALC;
                    next_idx = 4'd0;
                    next_min_val = 8'd255;
                    next_calc_done = 1'b0;
                    next_result_k = 8'd0;
                    next_no_quot = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_val <= 8'd0;
            idx <= 4'd0;
            result_k <= 8'd0;
            no_quot <= 1'b0;
            calc_done <= 1'b0;
        end else begin
            state <= next_state;
            min_val <= next_min_val;
            idx <= next_idx;
            result_k <= next_result_k;
            no_quot <= next_no_quot;
            calc_done <= next_calc_done;
        end
    end

endmodule