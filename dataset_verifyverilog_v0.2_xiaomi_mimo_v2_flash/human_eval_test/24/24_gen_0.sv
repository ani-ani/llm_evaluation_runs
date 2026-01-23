module largest_divisor (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam CHECK = 2'b01;
    localparam ITERATE = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state;
    reg [7:0] candidate;
    reg [7:0] n_reg;
    wire is_divisor;

    // Modulo check logic: check if n_reg % candidate == 0
    // We use repeated subtraction to avoid division operator for hardware efficiency
    // This combinational block calculates (n_reg % candidate == 0)
    reg [7:0] diff;
    integer i;
    
    always @(*) begin
        diff = n_reg;
        for (i = 0; i < 256; i = i + 1) begin
            if (diff >= candidate) 
                diff = diff - candidate;
        end
    end
    
    assign is_divisor = (diff == 8'd0);

    // State Transition and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            candidate <= 8'd0;
            n_reg <= 8'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        if (n <= 8'd1) begin
                            // Edge case: n <= 1, return 1 immediately
                            result <= 8'd1;
                            current_state <= DONE;
                        end else begin
                            // Start search from n-1
                            candidate <= n - 8'd1;
                            current_state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    // Check if current candidate divides n_reg
                    if (is_divisor) begin
                        result <= candidate;
                        current_state <= DONE;
                    end else begin
                        current_state <= ITERATE;
                    end
                end

                ITERATE: begin
                    // Decrement candidate
                    candidate <= candidate - 8'd1;
                    // Safety check: if candidate becomes 0, we failed to find a divisor (should not happen for n>1)
                    // but since 1 divides everything, we can default to 1 if we pass it
                    if (candidate == 8'd1) begin
                        result <= 8'd1;
                        current_state <= DONE;
                    end else begin
                        current_state <= CHECK;
                    end
                end

                DONE: begin
                    // Wait in done state until reset or new start
                    if (start) begin
                        // If start is asserted again, re-initialize like IDLE
                        n_reg <= n;
                        if (n <= 8'd1) begin
                            result <= 8'd1;
                            current_state <= DONE;
                        end else begin
                            candidate <= n - 8'd1;
                            current_state <= CHECK;
                        end
                        done <= 1'b0;
                    end else begin
                        done <= 1'b1;
                    end
                end

                default: current_state <= IDLE;
            endcase
        end
    end

endmodule