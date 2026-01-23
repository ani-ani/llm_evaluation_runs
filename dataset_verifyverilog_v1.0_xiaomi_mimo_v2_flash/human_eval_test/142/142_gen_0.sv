module sum_squares (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE       = 2'd2;

    reg [1:0] state;
    reg [4:0] index;          // 0-15 counter (5 bits)
    reg signed [31:0] sum;    // Accumulated sum
    reg signed [31:0] next_sum; // Combinational next value for sum
    reg done_flag;            // Internal done flag

    // For signed arithmetic
    reg signed [7:0] current_val;
    reg signed [15:0] squared;
    reg signed [23:0] cubed;

    // Determine operation based on index
    wire is_mult_of_3;
    wire is_mult_of_4;

    // Check modulo 3 (index % 3 == 0)
    assign is_mult_of_3 = (index % 5'd3 == 5'd0);
    // Check modulo 4 (index % 4 == 0)
    assign is_mult_of_4 = (index % 5'd4 == 5'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 5'd0;
            sum <= 32'sd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        index <= 5'd0;
                        sum <= 32'sd0;
                    end
                end

                PROCESSING: begin
                    // Accumulate based on current index
                    sum <= next_sum;
                    
                    // Check if we're done processing all 16 elements
                    if (index == 5'd15) begin
                        state <= DONE;
                        index <= 5'd0;
                    end else begin
                        index <= index + 5'd1;
                    end
                end

                DONE: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for next sum value
    always @(*) begin
        current_val = arr[index];
        squared = 16'sd0;
        cubed = 24'sd0;
        
        // Default: keep value unchanged
        next_sum = sum + {{24{current_val[7]}}, current_val};
        
        // If index % 3 == 0: square the value
        if (is_mult_of_3) begin
            squared = current_val * current_val;
            next_sum = sum + {{16{squared[15]}}, squared};
        end
        // Else if index % 4 == 0: cube the value
        else if (is_mult_of_4) begin
            cubed = current_val * current_val * current_val;
            next_sum = sum + {{8{cubed[23]}}, cubed};
        end
        // Else: keep value unchanged (already set as default)
    end

endmodule