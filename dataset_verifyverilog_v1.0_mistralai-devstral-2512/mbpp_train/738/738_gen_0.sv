module geometric_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] sum,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] iteration_count;
    reg [15:0] accumulator;
    reg [15:0] current_term;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            iteration_count <= 4'd0;
            accumulator <= 16'd0;
            current_term <= 16'd0;
            sum <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (n == 4'd0) begin
                            sum <= 16'd0;
                            done <= 1'b1;
                            next_state <= IDLE;
                        end else begin
                            accumulator <= 16'd0;
                            iteration_count <= 4'd0;
                            next_state <= COMPUTE;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    done <= 1'b0;
                    // Calculate current term: 256 >> iteration_count (Q8.8 format)
                    current_term <= 16'd256 >> iteration_count;
                    
                    // Add to accumulator
                    accumulator <= accumulator + current_term;
                    
                    // Increment iteration count
                    iteration_count <= iteration_count + 4'd1;
                    
                    // Check if all iterations completed
                    if (iteration_count == n) begin
                        sum <= accumulator;
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule