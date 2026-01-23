module jacobsthal (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [12:0] result,
    output reg done
);

    // State encoding
    localparam IDLE    = 3'b001;
    localparam CHECK   = 3'b010;
    localparam COMPUTE = 3'b100;
    // Note: DONE state is handled implicitly by the done signal and logic transitions
    // We use a 3-bit register to ensure safe state encoding

    reg [2:0] state;
    reg [3:0] i;              // Current index counter
    reg [12:0] j_prev;        // Stores J(i-1)
    reg [12:0] j_prev_prev;   // Stores J(i-2)
    reg [3:0] target_n;       // Latched input n

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 13'b0;
            done <= 1'b0;
            i <= 4'b0;
            j_prev <= 13'b0;
            j_prev_prev <= 13'b0;
            target_n <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        target_n <= n; // Latch n
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (target_n == 4'd0) begin
                        result <= 13'd0;
                        done <= 1'b1;
                        state <= IDLE;
                    end else if (target_n == 4'd1) begin
                        result <= 13'd1;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        // Initialize for computation: n >= 2
                        j_prev_prev <= 13'd0; // J(0)
                        j_prev <= 13'd1;      // J(1)
                        i <= 4'd2;            // Start computing from index 2
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // J(i) = J(i-1) + 2*J(i-2)
                    // Since j_prev is J(i-1) and j_prev_prev is J(i-2)
                    result <= j_prev + (j_prev_prev << 1);
                    
                    // Shift registers for next iteration
                    j_prev_prev <= j_prev;
                    j_prev <= j_prev + (j_prev_prev << 1);

                    if (i == target_n) begin
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        i <= i + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule