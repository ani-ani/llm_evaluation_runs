module painting2x2 (
    input clk, rst_n, start,
    input [3:0] target,
    output reg [3:0] painted,
    output reg [2:0] min_diff,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    // Registers
    reg [1:0] state;
    reg [1:0] white_idx;
    reg [1:0] black_idx;
    reg [2:0] current_cost;
    reg [2:0] min_cost;
    reg [1:0] best_white;
    reg [1:0] best_black;
    reg computation_complete;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            painted <= 4'd0;
            min_diff <= 3'd0;
            white_idx <= 2'd0;
            black_idx <= 2'd0;
            min_cost <= 3'd4; // Initialize to worst-case cost
            best_white <= 2'd0;
            best_black <= 2'd0;
            current_cost <= 3'd0;
            computation_complete <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        white_idx <= 2'd0;
                        black_idx <= 2'd0;
                        min_cost <= 3'd4;
                        computation_complete <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    if (!computation_complete) begin
                        if (white_idx < 3) begin
                            // Check current combination
                            if (white_idx != black_idx) begin
                                // Calculate cost for white quadrant (target=1 -> error=1, target=0 -> error=0)
                                // Calculate cost for black quadrant (target=1 -> error=0, target=0 -> error=1)
                                current_cost <= (target[white_idx] ? 3'd1 : 3'd0) + (target[black_idx] ? 3'd0 : 3'd1);
                                
                                // Update minimum cost if current is better
                                if (((target[white_idx] ? 3'd1 : 3'd0) + (target[black_idx] ? 3'd0 : 3'd1)) < min_cost) begin
                                    min_cost <= ((target[white_idx] ? 3'd1 : 3'd0) + (target[black_idx] ? 3'd0 : 3'd1));
                                    best_white <= white_idx;
                                    best_black <= black_idx;
                                end
                            end
                            
                            // Advance black index
                            if (black_idx < 3) begin
                                if (black_idx == 2'd2) begin
                                    black_idx <= 2'd0;
                                    white_idx <= white_idx + 2'd1;
                                end else begin
                                    black_idx <= black_idx + 2'd1;
                                end
                            end else begin
                                black_idx <= 2'd0;
                                white_idx <= white_idx + 2'd1;
                            end
                        end else begin
                            computation_complete <= 1'b1;
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    // Construct output: start with target, override white and black quadrants
                    painted <= target;
                    painted[best_white] <= 1'b0; // Force white quadrant to 0
                    painted[best_black] <= 1'b1; // Force black quadrant to 1
                    min_diff <= min_cost;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule