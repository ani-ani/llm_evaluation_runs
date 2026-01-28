module divisor_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [3:0] div_count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] ITERATE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [7:0] i;  // Iterator from 1 to n_in
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd256;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            div_count <= 4'd0;
            done <= 1'b0;
            i <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;  // Clear done when idle
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= ITERATE;
                        div_count <= 4'd0;
                        i <= 8'd1;  // Start from 1
                    end
                end

                ITERATE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if i is a divisor
                    if (n_in % i == 0) begin
                        div_count <= div_count + 4'd1;
                    end

                    // Move to next i
                    if (i == n_in || n_in == 8'd0) begin
                        state <= FINISH;
                    end else begin
                        i <= i + 8'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;  // Assert done
                    state <= IDLE;  // Return to idle
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule