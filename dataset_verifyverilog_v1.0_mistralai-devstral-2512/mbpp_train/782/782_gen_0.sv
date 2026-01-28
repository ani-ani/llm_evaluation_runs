module odd_length_subarray_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:7],
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Index and intermediate terms
    reg [3:0] i;
    reg [8:0] i_plus_1;
    reg [8:0] len_minus_i;
    reg [17:0] product;
    reg [16:0] term;
    reg signed [15:0] current_term;
    reg signed [15:0] accumulator;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            accumulator <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 4'd0;
                    accumulator <= 16'd0;
                    
                    if (start) begin
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute current term
                    i_plus_1 <= i + 4'd1;
                    len_minus_i <= len - i;
                    product <= i_plus_1 * len_minus_i;
                    term <= (product + 18'd1) >> 1;
                    current_term <= $signed(term) * arr[i];
                    
                    // Accumulate
                    accumulator <= accumulator + current_term;
                    
                    // Move to next index or finish
                    if (i == len - 4'd1) begin
                        next_state <= FINISH;
                    end else begin
                        i <= i + 4'd1;
                        next_state <= COMPUTE;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule